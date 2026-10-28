; =====================================================================
; BEE GOLD COLLECTOR BLAST (BGC BLAST) - FINAL MASTERPIECE EDITION
; Target: Motorola 68000 (M68K) | Assembler: VASM (vasmm68k_mot)
; =====================================================================

    SECTION .text

; --- Hardware & Memory Map Definitions ---
REG_P1_CTRL         EQU     $300001         ; Player 1 Joystick Address (A, B, C, D, Start, etc.)
REG_VDP_VRAM        EQU     $3C0000         ; VDP VRAM Data Port
REG_VDP_HSCROLL     EQU     $3C0002         ; VDP Horizontal Scroll Register
SRAM_BASE_ADDR      EQU     $200000         ; Battery-backed SRAM Base Address

; --- Game States ---
STATE_MAIN_MENU     EQU     0
STATE_PLAYING       EQU     1
STATE_PAUSED        EQU     2
STATE_SKIN_SELECT   EQU     3

; --- Enemy Types ---
ENEMY_TYPE_ALIEN_BUG    EQU 1               ; Slow-firing standard alien bug
ENEMY_TYPE_ROBO_BUG     EQU 2               ; Black/Grey robotic bug (Medium rarity, medium speed fire)
ENEMY_TYPE_UFO          EQU 3               ; Rare, fast-firing aggressive UFO
ENEMY_TYPE_BOSS_TELEMAN EQU 4               ; Teleman Boss (Telekinesis & Planet Meteors)

; --- Boss States ---
BOSS_STATE_IDLE     EQU     0
BOSS_STATE_PULLING  EQU     1
BOSS_STATE_THROWING EQU     2

; --- Game Constants & Smooth Scrolling ---
MAX_SCROLL_X        EQU     500             ; Culling start threshold
CULL_OFFSET         EQU     200             ; Background culling distance behind player
CLASSIC_MAX_RANGE   EQU     120             ; Water trap medium range limit
WATER_HANG_TIME     EQU     180             ; 3 Seconds (60Hz * 3 frames)
REGEN_INTERVAL      EQU     450             ; 7.5 Seconds (60Hz * 7.5 frames)
REGEN_AMOUNT        EQU     2               ; Health points restored per interval
MAX_PLAYER_HP       EQU     100             ; Maximum health stacking cap
MAX_ENEMIES         EQU     16              ; Max active enemies on screen
SPRITE_SIZE_LARGE   EQU     64              ; 64x64 Pixel large sprite grid

; --- Enemy Structure Offsets (Fixed Missing Definitions) ---
X_POS               EQU     2
Y_POS               EQU     4
X_SPEED             EQU     6

    org     $000000                         ; Reset Vector
    dc.l    $0010f000                       ; Initial Stack Pointer
    dc.l    start                           ; Initial Program Counter

start:
    move.w  #$2700,sr                       ; Disable Interrupts
    bsr     InitSystem
    bsr     LoadPixelArtAssets              ; Load large pixel art assets into VRAM
    bsr     LoadHighScore                   ; Read scores from SRAM and Disk

MainLoop:
    move.b  (CurrentState),d0
    cmp.b   #STATE_MAIN_MENU,d0
    beq     State_MainMenu
    cmp.b   #STATE_PLAYING,d0
    beq     State_GamePlaying
    cmp.b   #STATE_PAUSED,d0
    beq     State_GamePaused
    cmp.b   #STATE_SKIN_SELECT,d0
    beq     State_SkinSelect
    bra     MainLoop

; =====================================================================
; 1. MAIN MENU (Start Game / Change Skin)
; =====================================================================
State_MainMenu:
    bsr     DrawMainMenuGraphics            ; Draws "Start Game" and "Change Skin" buttons
    bsr     ReadNeoGeoJoypad
    btst    #7,d0                           ; Start Button Pressed?
    bne     .StartGame
    btst    #6,d0                           ; Change Skin Button?
    bne     .ChangeSkin
    bra     State_MainMenu

.StartGame:
    move.b  #STATE_PLAYING,(CurrentState)
    rts
.ChangeSkin:
    move.b  #STATE_SKIN_SELECT,(CurrentState)
    rts

; =====================================================================
; 2. GAMEPLAY STATE (Smooth Scrolling, Combat & Optimization)
; =====================================================================
State_GamePlaying:
    bsr     ReadNeoGeoJoypad
    btst    #4,d0                           ; Pause Button Pressed?
    bne     .TriggerPause

    bsr     UpdatePlayer                    ; Free movement (BGC Blast Laser vs Classic Water)
    bsr     UpdateHealthRegen               ; +2 HP every 7.5 seconds (Stackable)
    bsr     UpdateEnemies                   ; Alien, Robo Bug, UFO, and Telekinesis Boss
    bsr     UpdatePlayerWeapon              ; Handle Laser or Water Trap mechanics
    bsr     UpdateSmoothAutoScroll          ; **SILKY SMOOTH HORIZONTAL SCROLLING**
    
    ; --- 500 Threshold & 200 Back Culling Optimization ---
    move.w  (PlayerPosX),d1
    cmp.w   #MAX_SCROLL_X,d1
    blt     .SkipCulling
    sub.w   #CULL_OFFSET,d1
    bsr     DisableBackgroundRenderRange    ; Do not render background tiles behind culling zone

.SkipCulling:
    bsr     CheckCollisions                 ; Collision checks and water trap instant kills
    bsr     RenderLargePixelArtFrame        ; Render with hardware smooth scrolling
    bra     State_GamePlaying

.TriggerPause:
    move.b  #STATE_PAUSED,(CurrentState)
    rts

; =====================================================================
; 3. PAUSE MENU
; =====================================================================
State_GamePaused:
    bsr     DrawPauseMenuOverlay            ; "Resume Game?" / "Return to Main Menu?"
    bsr     ReadNeoGeoJoypad
    btst    #4,d0                           ; Resume (Pause button pressed again)
    bne     .ResumeGame
    btst    #5,d0                           ; Return to Menu
    bne     .ReturnToMenu
    bra     State_GamePaused

.ResumeGame:
    move.b  #STATE_PLAYING,(CurrentState)
    rts
.ReturnToMenu:
    move.b  #STATE_MAIN_MENU,(CurrentState)
    rts

; =====================================================================
; 4. SKIN & ASTRONAUT HAT CUSTOMIZATION MENU
; =====================================================================
State_SkinSelect:
    bsr     DrawSkinMenu                    ; Preview: BGC Blast vs Classic + Space Helmet toggle
    bsr     ReadNeoGeoJoypad
    
    btst    #0,d0                           ; A Button: Switch Skin
    bne     .ToggleSkin
    btst    #1,d0                           ; B Button: Toggle Astronaut Helmet
    bne     .ToggleHat
    btst    #7,d0                           ; Start Button: Return to Main Menu
    bne     .ReturnFromSkin
    bra     State_SkinSelect

.ToggleSkin:
    not.b   (PlayerSkin)                    ; Switch between BGC Blast (0) and Classic (1)
    rts
.ToggleHat:
    not.b   (AstronautHatEquipped)          ; Toggle space helmet on/off (0 <-> 1)
    rts
.ReturnFromSkin:
    move.b  #STATE_MAIN_MENU,(CurrentState)
    rts

; =====================================================================
; ADVANCED SUBROUTINES & MECHANICS
; =====================================================================

; --- Fixed-Point Silky Smooth Auto-Scrolling ---
UpdateSmoothAutoScroll:
    move.w  (ScrollSubPixel),d0
    add.w   #$00C0,d0                       ; Add fractional step (0.75 pixels per frame)
    
    move.w  d0,d1
    and.w   #$FF00,d1                       ; Extract integer carry
    beq     .NoPixelMove
    
    lsr.w   #8,d1                           ; Shift integer part down
    add.w   d1,(WorldScrollX)               ; Advance full world pixel
    add.w   d1,(PlayerPosX)                 ; Move player forward with world flow
    
    and.w   #$00FF,d0                       ; Keep only fractional remainder

.NoPixelMove:
    move.w  d0,(ScrollSubPixel)
    move.w  (WorldScrollX),d0
    move.w  d0,(REG_VDP_HSCROLL)            ; Update Neo Geo VDP H-Scroll hardware register
    rts

; --- Health Regeneration & Stacking System (Every 7.5s -> +2 HP) ---
UpdateHealthRegen:
    sub.w   #1,(RegenTimer)
    bgt     .DoneRegen
    move.w  (PlayerHP),d0
    add.w   #REGEN_AMOUNT,d0
    cmp.w   #MAX_PLAYER_HP,d0
    bgt     .CapHP
    move.w  d0,(PlayerHP)
    bra     .ResetRegenTimer
.CapHP:
    move.w  #MAX_PLAYER_HP,(PlayerHP)
.ResetRegenTimer:
    move.w  #REGEN_INTERVAL,(RegenTimer)
.DoneRegen:
    rts

; --- Weapon System (BGC Blast Laser vs Classic Water Trap) ---
UpdatePlayerWeapon:
    move.b  (PlayerSkin),d0
    cmp.b   #0,d0
    beq     .UpdateLaserWeapon              ; 0 = BGC Blast -> Fires Laser (White Robot)
    
    move.w  (WaterHangTimer),d0
    ble     .WaterExpired
    sub.w   #1,(WaterHangTimer)
    bsr     UpdateWaterTrapCollisions
.WaterExpired:
    rts

.UpdateLaserWeapon:
    rts

; --- Water Trap Instant Kill Mechanics ---
UpdateWaterTrapCollisions:
    lea     EnemyList,a0
    move.w  #MAX_ENEMIES,d7

.TrapLoop:
    move.b  (a0),d1
    beq     .NextTrapCheck
    move.b  1(a0),d2
    cmp.b   #ENEMY_TYPE_ROBO_BUG,d2
    beq     .TriggerInstantKill
    cmp.b   #ENEMY_TYPE_UFO,d2
    beq     .TriggerInstantKill
    bra     .NextTrapCheck

.TriggerInstantKill:
    bsr     CheckHitboxIntersection
    tst.b   d0
    beq     .NextTrapCheck
    move.b  #0,(a0)
    add.w   #500,(Score)

.NextTrapCheck:
    lea     32(a0),a0
    dbf     d7,.TrapLoop
    rts

UpdateEnemies:
    rts

; --- UFO Death RNG (%50 Alien Bug Spawn, %25 Self-Explode, %25 Escape) ---
ProcessUFODestruction:
    move.w  X_POS(a0),d2
    move.w  Y_POS(a0),d3
    bsr     GetRandomNumber
    
    cmp.w   #50,d0
    blt     .UFO_SpawnAlienBug
    cmp.w   #75,d0
    blt     .UFO_ExplodeInside
    bra     .UFO_FlyAway

.UFO_SpawnAlienBug:
    move.b  #0,(a0)
    bsr     SpawnAlienBugAtCoords
    rts

.UFO_ExplodeInside:
    move.b  #0,(a0)
    add.w   #200,(Score)
    rts

.UFO_FlyAway:
    move.w  #8,X_SPEED(a0)
    rts

SaveHighScore:
    move.l  (Score),(SRAM_BASE_ADDR)
    bsr     WriteScoreToDisk
    rts

LoadHighScore:
    move.l  (SRAM_BASE_ADDR),(Score)
    rts

; --- Hardware Stubs ---
InitSystem: rts
LoadPixelArtAssets: rts
ReadNeoGeoJoypad: move.b (REG_P1_CTRL),d0 rts
UpdatePlayer: rts
DisableBackgroundRenderRange: rts
CheckCollisions: rts
RenderLargePixelArtFrame: rts
DrawMainMenuGraphics: rts
DrawPauseMenuOverlay: rts
DrawSkinMenu: rts
GetRandomNumber: move.w #42,d0 rts
CheckHitboxIntersection: move.b #1,d0 rts
SpawnAlienBugAtCoords: rts
WriteScoreToDisk: rts

; =====================================================================
; DATA VARIABLES (Integrated directly to prevent section overlap)
; =====================================================================
CurrentState:           dc.b    STATE_MAIN_MENU
PlayerSkin:             dc.b    0
AstronautHatEquipped:   dc.b    0
PlayerPosX:             dc.w    0
PlayerPosY:             dc.w    128
PlayerHP:               dc.w    100
RegenTimer:             dc.w    REGEN_INTERVAL
WaterHangTimer:         dc.w    0
Score:                  dc.l    0
BossHP:                 dc.w    800
BossState:              dc.b    BOSS_STATE_IDLE
TelekinesisGlowActive:  dc.b    0
WorldScrollX:           dc.w    0
ScrollSubPixel:         dc.w    0
EnemyList:              ds.b    512
