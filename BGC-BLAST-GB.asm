; =====================================================================
; BGC BLAST - GAME BOY / SGB / CGB MASTER ROM
; =====================================================================

; --- RGBDS Donanım ve Register Sabitleri (8-bit Offsetler) ---
DEF rP1       EQU $00
DEF rSB       EQU $01
DEF rSC       EQU $02
DEF rDIV      EQU $04
DEF rTIMA     EQU $05
DEF rTMA      EQU $06
DEF rTAC      EQU $07
DEF rIF       EQU $0F
DEF rLCDC     EQU $40
DEF rSTAT     EQU $41
DEF rSCY      EQU $42
DEF rSCX      EQU $43
DEF rLY       EQU $44
DEF rLYC      EQU $45
DEF rDMA      EQU $46
DEF rBGP      EQU $47
DEF rOBP0     EQU $48
DEF rOBP1     EQU $49
DEF rWY       EQU $4A
DEF rWX       EQU $4B
DEF rIE       EQU $FF
DEF rCPU      EQU $50

DEF LCDCF_ON      EQU %10000000
DEF LCDCF_WINON   EQU %00100000
DEF LCDCF_WIN9800 EQU %01000000
DEF LCDCF_BG9600  EQU %00010000
DEF LCDCF_BG9800  EQU %00000000
DEF LCDCF_OBJ16   EQU %00000100
DEF LCDCF_OBJON   EQU %00000010
DEF LCDCF_BGON    EQU %00000001

; --- Game States ---
DEF STATE_INTRO             EQU 0  
DEF STATE_MAIN_MENU         EQU 1  
DEF STATE_PLAYING           EQU 2
DEF STATE_PAUSED            EQU 3
DEF STATE_SKIN_SELECT       EQU 4
DEF STATE_VERSUS_MENU       EQU 5
DEF STATE_VERSUS_PLAYING    EQU 6
DEF STATE_COLOR_CUSTOMIZE   EQU 7

; --- AI & Enemies ---
DEF AI_EASY                 EQU 1
DEF AI_MEDIUM               EQU 2
DEF AI_HARD                 EQU 3
DEF AI_EXPERT               EQU 4

; --- Game Constants ---
DEF MAX_PLAYER_HP           EQU 100
DEF VERSUS_REGEN_INTERVAL   EQU 300  
DEF VERSUS_REGEN_AMOUNT     EQU 5
DEF MAX_ENEMIES             EQU 16
DEF MAX_PLANETS             EQU 4
DEF METEOR_COOLDOWN_MAX     EQU 180

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
BossActive:           ds 1
VersusBotEnabled:     ds 1
VersusAIDifficulty:   ds 1
VersusRegenTimer:     ds 2
PauseCursorPos:       ds 1
VersusMenuCursor:     ds 1
RandomSeed:           ds 2
TelemanMeteorTimer:   ds 2  

PlayerCustom_bodyColor:      ds 1
PlayerCustom_stripeColor:    ds 1
PlayerCustom_grayPartColor:  ds 1
PlayerCustom_whitePartColor: ds 1
PlayerCustom_isDefault:      ds 1
PlayerCustom_wingsEquipped:  ds 1
PlayerCustom_engineEquipped: ds 1

EnemyList:            ds MAX_ENEMIES * 8
PlanetList:           ds MAX_PLANETS * 6
JoypadState:          ds 1  

; =====================================================================
; ROM HEADER & ENTRY POINT
; =====================================================================
SECTION "Header", ROM0[$0100]
    di
    jp EntryPoint

    ; Resmi Nintendo Logo Verisi (Zorunludur)
    db $CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83,$00,$0C,$00,$0D
    db $00,$08,$11,$1F,$88,$89,$00,$0E,$DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
    db $BB,$BB,$67,$63,$6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

    db "BGC BLAST", 0, 0, 0
    db $80          ; CGB Flag
    ds 2, 0         
    db $03          ; SGB Flag
    db $01          ; Kartuş Tipi
    db $00          
    db $00          
    db $33          ; Düzeltildi: Standart Lisans Kodu ($33)
    db $33          
    db $00          
    db $00          
    dw $0000        

EntryPoint:
    di
    ld sp, $FFFE

    ; 1. LCD'yi Güvenli Kapat
    xor a
    ldh [rLCDC], a

    ; 2. Sistem ve Grafik Verilerini Yükle (LCD Kapalıyken)
    call InitSystem
    call DetectHardwareAndPalettes
    call DetectSGBHardware

    ; 3. Her şey hazır, LCD'yi ve Arka Planı Aç
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ldh [rLCDC], a

MainLoop:
    call WaitVBlank
    call ReadJoypad

    ld a, [CurrentState]
    cp STATE_INTRO
    jr z, .st_intro
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
    jr MainLoop

.st_intro:
    call State_Intro_Logic
    jr MainLoop
.st_main:
    call State_MainMenu_Logic     
    jr MainLoop
.st_play:
    call State_GamePlaying_Logic  
    jr MainLoop
.st_pause:
    call State_GamePaused_Logic   
    jr MainLoop
.st_skin:
    call State_SkinSelect_Logic   
    jr MainLoop
.st_vmenu:
    call State_VersusMenu_Logic   
    jr MainLoop
.st_vplay:
    call State_VersusPlaying_Logic 
    jr MainLoop
.st_color:
    call State_ColorCustomize_Logic
    jr MainLoop

; =====================================================================
; SYSTEM INITIALIZATION (LCD KAPALIYKEN ÇALIŞIR)
; =====================================================================
InitSystem:
    ; DMG Renk Paletini Ayarla
    ld a, $E4       
    ldh [rBGP], a
    ldh [rOBP0], a
    ldh [rOBP1], a

    ; 1. KGAMER Font Verilerini VRAM'e Yükle ($8000 adresine)
    ld hl, $8000    
    ld de, KGAMER_FontData
    ld bc, KGAMER_FontDataEnd - KGAMER_FontData
.copyFont:
    ld a, [de]
    ld [hl], a
    inc hl
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyFont

    ; 2. Tilemap'i Temizle ($9800)
    ld hl, $9800
    ld bc, 1024
.clearMap:
    xor a
    ld [hl], a
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearMap

    ; 3. "KGAMER" Yazısını Ekranın Ortasına Yazdır ($982B)
    ld hl, $982B    
    ld [hl], $01    ; K
    inc hl
    ld [hl], $02    ; G
    inc hl
    ld [hl], $03    ; A
    inc hl
    ld [hl], $04    ; M
    inc hl
    ld [hl], $05    ; E
    inc hl
    ld [hl], $06    ; R

    ; Başlangıç Durumunu INTRO Yap
    ld a, STATE_INTRO
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
    ld [BossActive], a
    
    ld hl, METEOR_COOLDOWN_MAX
    ld a, l
    ld [TelemanMeteorTimer], a
    ld a, h
    ld [TelemanMeteorTimer + 1], a

    call InitPlanets

    ld hl, 16
    ld a, l 
    ld [Player1PosX], a 
    ld a, h 
    ld [Player1PosX + 1], a
    
    ld hl, 80
    ld a, l 
    ld [Player1PosY], a 
    ld a, h 
    ld [Player1PosY + 1], a
    
    ld hl, 136
    ld a, l 
    ld [Player2PosX], a 
    ld a, h 
    ld [Player2PosX + 1], a
    
    ld hl, 80
    ld a, l 
    ld [Player2PosY], a 
    ld a, h 
    ld [Player2PosY + 1], a
    
    ld hl, 100
    ld a, l 
    ld [Player1HP], a 
    ld a, h 
    ld [Player1HP + 1], a
    
    ld a, l 
    ld [Player2HP], a 
    ld a, h 
    ld [Player2HP + 1], a
    
    ld hl, 800
    ld a, l 
    ld [BossHP], a 
    ld a, h 
    ld [BossHP + 1], a
    
    ld hl, VERSUS_REGEN_INTERVAL
    ld a, l 
    ld [VersusRegenTimer], a 
    ld a, h 
    ld [VersusRegenTimer + 1], a
    ret

; =====================================================================
; KGAMER FONT PIXEL DATA (8x8 Harf Çizimleri)
; =====================================================================
KGAMER_FontData:
; K (Tile 1)
    db $42,$44,$48,$F0,$48,$44,$42,$00
; G (Tile 2)
    db $3C,$42,$40,$4C,$42,$42,$3C,$00
; A (Tile 3)
    db $18,$24,$42,$7E,$42,$42,$42,$00
; M (Tile 4)
    db $82,$C6,$AA,$92,$82,$82,$82,$00
; E (Tile 5)
    db $7E,$40,$40,$7C,$40,$40,$7E,$00
; R (Tile 6)
    db $7C,$42,$42,$7C,$48,$44,$42,$00
KGAMER_FontDataEnd:

InitPlanets:
    ld hl, PlanetList
    ld [hl], 1       
    inc hl
    ld de, 32        
    ld [hl], e 
    inc hl 
    ld [hl], d 
    inc hl
    ld de, 24        
    ld [hl], e 
    inc hl 
    ld [hl], d 
    inc hl
    
    ld hl, PlanetList + 6
    ld [hl], 1
    inc hl
    ld de, 128
    ld [hl], e 
    inc hl 
    ld [hl], d 
    inc hl
    ld de, 112
    ld [hl], e 
    inc hl 
    ld [hl], d 
    inc hl
    ret

DetectHardwareAndPalettes:
    ldh a, [rCPU]
    cp $11
    jr z, .isCGB
    ld a, 0
    ld [HardwareMode], a
    ret
.isCGB:
    ld a, 1
    ld [HardwareMode], a
    ret

DetectSGBHardware:
    ld a, 1
    ld [IsSuperGameBoy], a
    ret

; --- DÜZELTİLDİ: Güvenli VBlank Bekleme Rutini ---
WaitVBanner:
WaitVBlank:
    ldh a, [rLY]
    cp 144
    jr nc, WaitVBlank     ; 144 ve üzeriyse VBlank dışına çıkmasını bekle
.waitV:
    ldh a, [rLY]
    cp 144
    jr c, .waitV          ; 144'ün altındaysa VBlank'e girmesini bekle
    ret

; =====================================================================
; ROBUST JOYPAD READING ROUTINE
; =====================================================================
ReadJoypad:
    ld a, $20
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]        
    cpl                 
    and $0F
    swap a              
    ld b, a

    ld a, $10
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    ldh a, [rP1]
    cpl
    and $0F
    or b                
    ld [JoypadState], a
    
    ld a, $30
    ldh [rP1], a
    ret

GetRandomNumber:
    ld hl, RandomSeed
    ld a, [hl]
    inc a
    ld [hl], a
    ret

CheckAndSpawnTelemanMeteors:
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
    ld a, l
    ld [TelemanMeteorTimer], a
    ld a, h
    ld [TelemanMeteorTimer + 1], a
    ret

SpawnEnemyAtCoords:
    ret

; =====================================================================
; GAME STATES & LOGIC (INTRO & MENUS)
; =====================================================================

State_Intro_Logic:
    ld a, [JoypadState]
    bit 3, a            ; Start tuşuna basıldı mı?
    ret z
    
    ; Ekranı temizle ve Ana Menüye geç
    ld hl, $9800
    ld bc, 1024
.clearForMenu:
    xor a
    ld [hl], a
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearForMenu

    ld a, STATE_MAIN_MENU
    ld [CurrentState], a
    ret

State_MainMenu_Logic:
    ld a, [JoypadState]
    bit 3, a            ; Start -> Oynama Başlat
    jr nz, .startPlay
    bit 2, a            ; Select -> Versus Menu
    jr nz, .startVersusMenu
    bit 0, a            ; A -> Skin Select
    jr nz, .startSkinSelect
    bit 1, a            ; B -> Color Customize
    jr nz, .startColorCustomize
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
    ld a, [JoypadState]
    bit 0, a            
    jr nz, .toggleSkin
    bit 3, a            
    jr nz, .returnMain
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
    ld a, [JoypadState]
    bit 6, a            
    jr nz, .cursorUp
    bit 7, a            
    jr nz, .cursorDown
    bit 4, a            
    jr nz, .confirmSelection
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
    ld a, [JoypadState]
    bit 3, a
    ret z
    ld a, STATE_VERSUS_PLAYING
    ld [PreviousState], a
    ld a, STATE_PAUSED
    ld [CurrentState], a
    ret

State_GamePlaying_Logic:
    ld a, [JoypadState]
    bit 3, a 
    jr z, .noPause
    ld a, STATE_PLAYING
    ld [PreviousState], a
    ld a, STATE_PAUSED
    ld [CurrentState], a
    ret
.noPause:
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
