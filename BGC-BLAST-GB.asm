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

; --- Enemy & Entity Types ---
DEF ENEMY_TYPE_ALIEN_BUG    EQU 1
DEF ENEMY_TYPE_ROBO_BUG     EQU 2
DEF ENEMY_TYPE_UFO          EQU 3
DEF ENEMY_TYPE_BOSS_TELEMAN EQU 4
DEF ENEMY_TYPE_METEOR       EQU 5 ; Yalnızca Teleman'in gezegenden koparıp fırlattığı özel mermi

; --- Game Constants ---
DEF MAX_PLAYER_HP           EQU 100
DEF VERSUS_REGEN_INTERVAL   EQU 300
DEF VERSUS_REGEN_AMOUNT     EQU 5
DEF MAX_ENEMIES             EQU 16
DEF MAX_PLANETS             EQU 4
DEF METEOR_COOLDOWN_MAX     EQU 180 ; Teleman'in meteor koparma sıklığı

; --- Structure Offsets ---
DEF ENEMY_ACTIVE            EQU 0
DEF ENEMY_TYPE              EQU 1
DEF ENEMY_X_POS             EQU 2
DEF ENEMY_Y_POS             EQU 4

DEF PLANET_ACTIVE           EQU 0
DEF PLANET_X_POS            EQU 1
DEF PLANET_Y_POS            EQU 3

; --- Variables Section (WRAM) ---
SECTION "GameVariables", WRAM0
CurrentState:         ds 1
PreviousState:        ds 1
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
BossActive:           ds 1  ; 0 = Teleman yok (sadece bozuk robotlar var), 1 = Teleman aktif (gezegenden meteor fırlatabilir)
VersusBotEnabled:     ds 1
VersusAIDifficulty:   ds 1
VersusRegenTimer:     ds 2
PauseCursorPos:       ds 1
VersusMenuCursor:     ds 1
RandomSeed:           ds 2

; --- Teleman & Planet Mechanics ---
TelemanMeteorTimer:   ds 2  

; --- Character Customization Struct ---
PlayerCustom_bodyColor:      ds 1
PlayerCustom_stripeColor:    ds 1
PlayerCustom_grayPartColor:  ds 1
PlayerCustom_whitePartColor: ds 1
PlayerCustom_isDefault:      ds 1
PlayerCustom_wingsEquipped:  ds 1
PlayerCustom_engineEquipped: ds 1

; --- Entity Arrays ---
EnemyList:            ds MAX_ENEMIES * 8
PlanetList:           ds MAX_PLANETS * 6

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
; SYSTEM INITIALIZATION
; =====================================================================
InitSystem:
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a
    
    ld a, STATE_MAIN_MENU
    ld [CurrentState], a
    ld a, STATE_PLAYING
    ld [PreviousState], a
    ld a, 1
    ld [StarFieldActive], a
    ld a, AI_MEDIUM
    ld [VersusAIDifficulty], a
    ld a, 1
    ld [VersusBotEnabled], a
    ld a, 1
    ld [DMG_PaletteChoice], a
    xor a
    ld [PauseCursorPos], a
    ld [VersusMenuCursor], a
    ld [PlayerSkin], a
    ld [BossActive], a ; Başlangıçta Teleman yok, sadece bozuk robotlar var
    
    ld hl, METEOR_COOLDOWN_MAX
    ld [TelemanMeteorTimer], hl

    ; Gezegenleri oluştur (Başlangıçta üzerlerinde hazır meteor yoktur)
    call InitPlanets

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

InitPlanets:
    ld hl, PlanetList
    
    ; Gezegen 1 (Başlangıçta saf gezegen, meteor yok)
    ld [hl], 1       
    inc hl
    ld de, 32        
    ld [hl], e : inc hl : ld [hl], d : inc hl
    ld de, 24        
    ld [hl], e : inc hl : ld [hl], d : inc hl
    
    ; Gezegen 2 (Başlangıçta saf gezegen, meteor yok)
    ld hl, PlanetList + 6
    ld [hl], 1
    inc hl
    ld de, 128
    ld [hl], e : inc hl : ld [hl], d : inc hl
    ld de, 112
    ld [hl], e : inc hl : ld [hl], d : inc hl
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

; =====================================================================
; BOSS TELEMAN: GEZEGENLERDEN METEOR KOPARMA (SADECE TELEMAN AKTİFKEN)
; =====================================================================
CheckAndSpawnTelemanMeteors:
    ; Eğer Boss (Teleman) henüz sahneye çıkmadıysa meteor fırlatmaz (Sadece bozuk robotlar vardır)
    ld a, [BossActive]
    and a
    ret z

    ld hl, TelemanMeteorTimer
    ld a, [hl]
    and a
    jr z, .telemanRipMeteorFromPlanet
    dec [hl]
    ret

.telemanRipMeteorFromPlanet:
    ld hl, METEOR_COOLDOWN_MAX
    ld [TelemanMeteorTimer], hl

    ; Aktif gezegeni bul ve oradan meteor koparıp fırlat
    ld hl, PlanetList
    ld a, [hl]
    and a
    ret z

    inc hl
    ld e, [hl] : inc hl : ld d, [hl] : inc hl
    ld c, [hl] : inc hl : ld b, [hl]

    ld a, ENEMY_TYPE_METEOR
    call SpawnEnemyAtCoords
    ret

SpawnEnemyAtCoords:
    push af
    push de
    push bc
    ld hl, EnemyList
    ld b, MAX_ENEMIES
.findSlot:
    ld a, [hl]
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
    ld [hl], 1
    inc hl
    ld [hl], a
    inc hl
    ld [hl], e
    inc hl
    ld [hl], d
    inc hl
    ld [hl], c
    inc hl
    ld [hl], b
    ret

; =====================================================================
; MENÜLER VE OYUN DÖNGÜSÜ
; =====================================================================
State_MainMenu_Logic:
    ldh a, [rP1]
    ld b, a
    bit 3, b : jr nz, .startPlay
    bit 2, b : jr nz, .startVersusMenu
    bit 0, b : jr nz, .startSkinSelect
    bit 1, b : jr nz, .startColorCustomize
    ret

.startPlay:
    ld a, STATE_PLAYING
    ld [CurrentState], a
    ld [PreviousState], a
    ret
.startVersusMenu:
    ld a, STATE_VERSUS_MENU
    ld [CurrentState], a
    ret
.startSkinSelect:
    ld a, STATE_SKIN_SELECT
    ld [CurrentState], a
    ret
.startColorCustomize:
    ld a, STATE_COLOR_CUSTOMIZE
    ld [CurrentState], a
    ret

State_SkinSelect_Logic:
    ldh a, [rP1]
    ld b, a
    bit 0, b : jr nz, .toggleSkin
    bit 3, b : jr nz, .returnMain
    ret
.toggleSkin:
    ld a, [PlayerSkin]
    xor 1
    ld [PlayerSkin], a
    ret
.returnMain:
    ld a, STATE_MAIN_MENU
    ld [CurrentState], a
    ret

State_VersusMenu_Logic:
    ret

State_GamePaused_Logic:
    ldh a, [rP1]
    ld b, a
    bit 6, b : jr nz, .cursorUp
    bit 7, b : jr nz, .cursorDown
    bit 0, b : jr nz, .confirmSelection
    ret
.cursorUp:
    xor a
    ld [PauseCursorPos], a
    ret
.cursorDown:
    ld a, 1
    ld [PauseCursorPos], a
    ret
.confirmSelection:
    ld a, [PauseCursorPos]
    and a
    jr z, .resumeGame
    ld a, STATE_MAIN_MENU
    ld [CurrentState], a
    xor a
    ld [PauseCursorPos], a
    ret
.resumeGame:
    ld a, [PreviousState]
    ld [CurrentState], a
    xor a
    ld [PauseCursorPos], a
    ret

State_ColorCustomize_Logic:
    ret

State_VersusPlaying_Logic:
    ldh a, [rP1]
    bit 3, a
    ret z
    ld a, STATE_VERSUS_PLAYING
    ld [PreviousState], a
    ld a, STATE_PAUSED
    ld [CurrentState], a
    ret

State_GamePlaying_Logic:
    ldh a, [rP1]
    bit 3, a 
    jr z, .noPause
    ld a, STATE_PLAYING
    ld [PreviousState], a
    ld a, STATE_PAUSED
    ld [CurrentState], a
    ret
.noPause:

    ; Normal modda başıboş meteorlar yerine sadece bozuk robotlar ve Teleman aktifse gezegen meteorları çalışır
    call CheckAndSpawnTelemanMeteors
    call UpdateNormalModeEnemies
    ret

UpdateNormalModeEnemies:
    ld hl, EnemyList
    ld b, MAX_ENEMIES
.enemyLoop:
    ld a, [hl]
    and a
    jr z, .nextEnemy
.nextEnemy:
    ld de, 8
    add hl, de
    dec b
    jr nz, .enemyLoop
    ret
