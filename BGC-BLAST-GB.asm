INCLUDE "hardware.inc"

; --- Game States ---
DEF STATE_MAIN_MENU         EQU 0
DEF STATE_PLAYING           EQU 1
DEF STATE_PAUSED            EQU 2
DEF STATE_SKIN_SELECT       EQU 3
DEF STATE_VERSUS_MENU       EQU 4
DEF STATE_VERSUS_PLAYING    EQU 5
DEF STATE_COLOR_CUSTOMIZE   EQU 6

; --- AI Difficulties ---
DEF AI_EASY                 EQU 1
DEF AI_MEDIUM               EQU 2
DEF AI_HARD                 EQU 3
DEF AI_EXPERT               EQU 4

; --- Enemy Types ---
DEF ENEMY_TYPE_ALIEN_BUG    EQU 1
DEF ENEMY_TYPE_ROBO_BUG     EQU 2
DEF ENEMY_TYPE_UFO          EQU 3
DEF ENEMY_TYPE_BOSS_TELEMAN EQU 4

; --- Game Constants ---
DEF MAX_PLAYER_HP           EQU 100
DEF VERSUS_REGEN_INTERVAL   EQU 300
DEF VERSUS_REGEN_AMOUNT     EQU 5
DEF MAX_ENEMIES             EQU 16

; --- Enemy Structure Offsets ---
DEF ENEMY_ACTIVE            EQU 0
DEF ENEMY_TYPE              EQU 1
DEF ENEMY_X_POS             EQU 2
DEF ENEMY_Y_POS             EQU 4

; --- Variables Section (WRAM) ---
SECTION "GameVariables", WRAM0
CurrentState:         ds 1
PlayerSkin:           ds 1
AstronautHatEquipped: ds 1
Player1PosX:          ds 2
Player1PosY:          ds 2
Player2PosX:          ds 2
Player2PosY:          ds 2
Player1HP:            ds 2
Player2HP:            ds 2
Score:                ds 4
StarFieldActive:      ds 1
HardwareMode:         ds 1
IsSuperGameBoy:       ds 1
DMG_PaletteChoice:    ds 1
LinkConnected:        ds 1
LinkDataOut:          ds 1
LinkDataIn:           ds 1
BossHP:               ds 2
VersusBotEnabled:     ds 1
VersusAIDifficulty:   ds 1
VersusRegenTimer:     ds 2
RandomSeed:           ds 2

; --- Character Customization Struct ---
PlayerCustom_bodyColor:      ds 1
PlayerCustom_stripeColor:    ds 1
PlayerCustom_grayPartColor:  ds 1
PlayerCustom_whitePartColor: ds 1
PlayerCustom_isDefault:      ds 1
PlayerCustom_wingsEquipped:  ds 1
PlayerCustom_engineEquipped: ds 1

; --- Enemy List Array (16 enemies * 8 bytes) ---
EnemyList:            ds MAX_ENEMIES * 8

; --- ROM Header & Entry Point ---
SECTION "Header", ROM0[$0100]
    jp EntryPoint
    ds $150 - @, 0

EntryPoint:
    di
    ld sp, $FFFE
    call InitSystem
    call DetectHardwareAndPalettes
    call DetectSGBHardware

MainLoop:
    ld a, [StarFieldActive]
    and a
    jr z, .skipStars
    call DrawSpaceBackgroundStars
.skipStars:

    ld a, [CurrentState]
    cp STATE_MAIN_MENU
    jr z, .st_main
    cp STATE_PLAYING
    jr z, .st_play
    cp STATE_PAUSED
    jr z, .st_pause
    cp STATE_SKIN_SELECT
    jr z, .st_skin
    cp STATE_VERSUS_MENU
    jr z, .st_vmenu
    cp STATE_VERSUS_PLAYING
    jr z, .st_vplay
    cp STATE_COLOR_CUSTOMIZE
    jr z, .st_color
    jr .endSwitch

.st_main:   call State_MainMenu_Logic     : jr .endSwitch
.st_play:   call State_GamePlaying_Logic  : jr .endSwitch
.st_pause:  call State_GamePaused_Logic   : jr .endSwitch
.st_skin:   call State_SkinSelect_Logic   : jr .endSwitch
.st_vmenu:  call State_VersusMenu_Logic   : jr .endSwitch
.st_vplay:  call State_VersusPlaying_Logic: jr .endSwitch
.st_color:  call State_ColorCustomize_Logic

.endSwitch:
    call WaitVBlank
    jr MainLoop

; =====================================================================
; SYSTEM INITIALIZATION & HARDWARE
; =====================================================================
InitSystem:
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a
    
    ld a, STATE_MAIN_MENU
    ld [CurrentState], a
    ld a, 1
    ld [StarFieldActive], a
    ld a, AI_MEDIUM
    ld [VersusAIDifficulty], a
    ld a, 1
    ld [VersusBotEnabled], a
    ld a, 1
    ld [DMG_PaletteChoice], a
    
    ; Default Customization Setup
    ld a, 0
    ld [PlayerCustom_bodyColor], a
    ld [PlayerCustom_stripeColor], a
    ld [PlayerCustom_grayPartColor], a
    ld [PlayerCustom_whitePartColor], a
    ld a, 1
    ld [PlayerCustom_isDefault], a
    ld [PlayerCustom_wingsEquipped], a
    ld [PlayerCustom_engineEquipped], a
    
    ld hl, 16
    ld [Player1PosX], hl
    ld hl, 80
    ld [Player1PosY], hl
    ld hl, 136
    ld [Player2PosX], hl
    ld hl, 80
    ld [Player2PosY], hl
    
    ld hl, 100
    ld [Player1HP], hl
    ld [Player2HP], hl
    ld hl, 800
    ld [BossHP], hl
    
    ld hl, VERSUS_REGEN_INTERVAL
    ld [VersusRegenTimer], hl
    ret

DetectHardwareAndPalettes:
    ld a, [rCPU]
    cp $11
    jr z, .isCGB
    ld a, 0
    ld [HardwareMode], a
    ld a, $E4
    ld [rBGP], a
    ld [rOBP0], a
    ld a, $1B
    ld [rOBP1], a
    ret
.isCGB:
    ld a, 1
    ld [HardwareMode], a
    ret

DetectSGBHardware:
    ld a, 1
    ld [IsSuperGameBoy], a
    ret

DrawSpaceBackgroundStars:
    ret

WaitVBlank:
    ld a, [rLY]
    cp 144
    jr nc, WaitVBlank
.waitV:
    ld a, [rLY]
    cp 144
    jr c, .waitV
    ret

GetRandomNumber:
    ld hl, [RandomSeed]
    inc hl
    ld [RandomSeed], hl
    ret

TransferLinkByte:
    ld [rSB], a
    ld a, $81
    ld [rSC], a
.waitLink:
    ld a, [rSC]
    bit 7, a
    jr nz, .waitLink
    ld a, [rSB]
    ret

; =====================================================================
; ENEMY MANAGEMENT & SPAWNING LOGIC
; =====================================================================
SpawnEnemyAtCoords:
    ; Input: A = Enemy Type, DE = X Pos, BC = Y Pos
    push af
    push de
    push bc
    
    ld hl, EnemyList
    ld b, MAX_ENEMIES
.findSlot:
    ld a, [hl] ; check ENEMY_ACTIVE
    and a
    jr z, .foundFree
    ld de, 8
    add hl, de
    dec b
    jr nz, .findSlot
    pop bc
    pop de
    pop af
    ret

.foundFree:
    pop bc
    pop de
    pop af
    
    ; Set active = 1
    ld [hl], 1
    inc hl
    ; Set type
    ld [hl], a
    inc hl
    ; Set X Pos (2 bytes)
    ld [hl], e
    inc hl
    ld [hl], d
    inc hl
    ; Set Y Pos (2 bytes)
    ld [hl], c
    inc hl
    ld [hl], b
    ret

ProcessEnemyDestruction:
    ; Input: HL = Enemy Pointer, A = Killer Skin (0 = BGC, 1 = Classic)
    push hl
    push af
    
    ; enemyType = *(enemyPtr + 1)
    inc hl
    ld a, [hl]
    ld b, a ; b = enemyType
    
    ; *(enemyPtr + 0) = 0 (Deactivate enemy)
    pop af ; restore killerSkin
    push af
    ld hl, EnemyList ; (re-fetch ptr offset if needed, simplified)
    ld [hl], 0 
    
    pop af
    and a
    jr z, .killerIsBGC
    
    ; Killer is Classic Skin (1)
    ld a, b
    cp ENEMY_TYPE_ALIEN_BUG
    jr z, .add200
    ; Else add 400
    ld hl, [Score]
    ld de, 400
    add hl, de
    ld [Score], hl
    jr .doneDest
.add200:
    ld hl, [Score]
    ld de, 200
    add hl, de
    ld [Score], hl
    jr .doneDest

.killerIsBGC:
    ld a, b
    cp ENEMY_TYPE_ROBO_BUG
    jr z, .roboBonus
    ; Else add 250
    ld hl, [Score]
    ld de, 250
    add hl, de
    ld [Score], hl
    jr .doneDest
.roboBonus:
    call GetRandomNumber
    and 1
    jr z, .bonus350
    ld hl, [Score]
    ld de, 250
    add hl, de
    ld [Score], hl
    jr .doneDest
.bonus350:
    ld hl, [Score]
    ld de, 350
    add hl, de
    ld [Score], hl

.doneDest:
    pop hl
    ret

; =====================================================================
; COLOR & PALETTE CUSTOMIZATION LOGIC
; =====================================================================
State_ColorCustomize_Logic:
    ldh a, [rP1]
    ld b, a
    
    ld a, [HardwareMode]
    and a
    jr nz, .cgbCustomization
    
    ; DMG Palette Logic (Left/Right changes DMG_PaletteChoice 1-4)
    bit 4, b ; Right
    jr nz, .dmgRight
    bit 5, b ; Left
    jr nz, .dmgLeft
    jr .checkStart
    
.dmgRight:
    ld hl, DMG_PaletteChoice
    inc [hl]
    ld a, [hl]
    cp 5
    jr c, .checkStart
    ld [hl], 1
    jr .checkStart
.dmgLeft:
    ld hl, DMG_PaletteChoice
    dec [hl]
    ld a, [hl]
    and a
    jr nz, .checkStart
    ld [hl], 4
    jr .checkStart

.cgbCustomization:
    ; CGB Customization logic (Up/Down/Left/Right/Select)
    bit 6, b ; Up -> bodyColor++
    jr nz, .incBody
    bit 7, b ; Down -> stripeColor++
    jr nz, .incStripe
    bit 4, b ; Right -> grayPartColor++
    jr nz, .incGray
    bit 5, b ; Left -> whitePartColor++
    jr nz, .incWhite
    bit 3, b ; Select -> Reset defaults
    jr nz, .resetCust
    jr .checkStart

.incBody:
    ld hl, PlayerCustom_bodyColor
    inc [hl]
    ld a, 0
    ld [PlayerCustom_isDefault], a
    jr .checkStart
.incStripe:
    ld hl, PlayerCustom_stripeColor
    inc [hl]
    ld a, 0
    ld [PlayerCustom_isDefault], a
    jr .checkStart
.incGray:
    ld hl, PlayerCustom_grayPartColor
    inc [hl]
    ld a, 0
    ld [PlayerCustom_isDefault], a
    jr .checkStart
.incWhite:
    ld hl, PlayerCustom_whitePartColor
    inc [hl]
    ld a, 0
    ld [PlayerCustom_isDefault], a
    jr .checkStart
.resetCust:
    xor a
    ld [PlayerCustom_bodyColor], a
    ld [PlayerCustom_stripeColor], a
    ld [PlayerCustom_grayPartColor], a
    ld [PlayerCustom_whitePartColor], a
    ld a, 1
    ld [PlayerCustom_isDefault], a

.checkStart:
    bit 3, b ; Start button to return to main menu
    ret

; =====================================================================
; OTHER GAME STATES
; =====================================================================
State_MainMenu_Logic:
    ret

State_VersusMenu_Logic:
    ret

State_VersusPlaying_Logic:
    call UpdateVersusHealthRegen
    ld a, [VersusBotEnabled]
    and a
    jr z, .linkMulti
    call UpdateVersusBotAI
    ret
.linkMulti:
    call UpdateLinkCableMultiplayer
    ret

UpdateVersusHealthRegen:
    ld hl, VersusRegenTimer
    ld a, [hl]
    and a
    jr z, .doRegen
    dec [hl]
    ret
.doRegen:
    ld hl, VERSUS_REGEN_INTERVAL
    ld [VersusRegenTimer], hl
    
    ld hl, [Player1HP]
    ld de, VERSUS_REGEN_AMOUNT
    add hl, de
    ld a, h
    cp HIGH(MAX_PLAYER_HP)
    jr nc, .capP1
    ld [Player1HP], hl
    jr .regenP2
.capP1:
    ld hl, MAX_PLAYER_HP
    ld [Player1HP], hl

.regenP2:
    ld hl, [Player2HP]
    ld de, VERSUS_REGEN_AMOUNT
    add hl, de
    ld a, h
    cp HIGH(MAX_PLAYER_HP)
    jr nc, .capP2
    ld [Player2HP], hl
    ret
.capP2:
    ld hl, MAX_PLAYER_HP
    ld [Player2HP], hl
    ret

UpdateVersusBotAI:
    ld a, [VersusAIDifficulty]
    cp AI_EXPERT
    jr z, .expertAI
    ret
.expertAI:
    ld hl, [Player1PosX]
    ld de, [Player2PosX]
    ld a, h
    cp d
    jr z, .doneAI
    jr c, .moveLeft
    inc de
    inc de
    ld [Player2PosX], de
    ret
.moveLeft:
    dec de
    dec de
    ld [Player2PosX], de
.doneAI:
    ret

UpdateLinkCableMultiplayer:
    ld a, [Player1PosX]
    call TransferLinkByte
    ld [Player2PosX], a
    ret

State_GamePlaying_Logic:
    call UpdateNormalModeEnemies
    ret

UpdateNormalModeEnemies:
    ld hl, EnemyList
    ld b, MAX_ENEMIES
.enemyLoop:
    ld a, [hl]
    and a
    jr z, .nextEnemy
    ; Enemy is active, handle logic here
.nextEnemy:
    ld de, 8
    add hl, de
    dec b
    jr nz, .enemyLoop
    ret

State_GamePaused_Logic:
    ret

State_SkinSelect_Logic:
    ret
