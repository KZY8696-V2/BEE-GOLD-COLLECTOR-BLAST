; =====================================================================
; BGC BLAST - GAME BOY / SGB 1 & 2 / CGB / LINK CABLE MASTER ROM
; =====================================================================

INCLUDE "hardware.inc"

; --- hardware.inc içinde eksik olabilecek sabitler ---
DEF rCPU          EQU $FF56
DEF LCDCF_ON      EQU %10000000
DEF LCDCF_BGON    EQU %00000001
DEF LCDCF_OBJON   EQU %00000010

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
; ROM HEADER (ZORUNLU NINTENDO ALANI - $0100 - $014F)
; =====================================================================
SECTION "Header", ROM0[$0100]
    di
    jp EntryPoint

    ; Resmi Nintendo Logo Verisi (ASLA değiştirilemez - emülatör açılış şartıdır)
    db $CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83,$00,$0C,$00,$0D
    db $00,$08,$11,$1F,$88,$89,$00,$0E,$DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
    db $BB,$BB,$67,$63,$6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

    db "BGC BLAST", 0, 0, 0   ; Oyun Başlığı (16 Bayt)
    db $80                    ; CGB Flag ($80 = CGB/DMG uyumlu)
    db $00,$00                ; Yeni Lisans Kodu
    db $03                    ; SGB Flag ($03 = Super Game Boy 1 & 2 Destekler)
    db $01                    ; Kartuş Tipi (ROM ONLY)
    db $00                    ; ROM Boyutu (32KB)
    db $00                    ; RAM Boyutu (Yok)
    db $33                    ; Eski Lisans Kodu ($33)
    db $01                    ; Mask ROM Sürümü
    db $00                    ; Header Checksum (rgbfix otomatik doldurur)
    dw $0000                  ; Global Checksum (rgbfix otomatik doldurur)

; =====================================================================
; ENTRY POINT (KODUN BAŞLADIĞI KESİN NOKTA - $0150)
; =====================================================================
SECTION "GameEntry", ROM0[$0150]
EntryPoint:
    di
    ld sp, $FFFE

    ; LCD Kapatılmadan Önce Güvenli VBlank Beklemesi
.waitVBL_Startup:
    ldh a, [rLY]
    cp 144
    jr nc, .waitVBL_Startup
.waitVBL_Startup2:
    ldh a, [rLY]
    cp 144
    jr c, .waitVBL_Startup2

    ; 1. LCD'yi Güvenli Kapat
    xor a
    ldh [rLCDC], a

    ; 2. Sistem, Grafik, SGB ve Link Kablosu Başlatma Verilerini Yükle
    call InitSystem
    call DetectHardwareAndPalettes
    call InitSGBSupport       
    call InitLinkCable        ; Game Boy Link Kablosu Başlatma

    ; 3. LCD'yi ve Arka Planı Aç
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ldh [rLCDC], a

MainLoop:
    call WaitVBlank
    call ReadJoypad
    call UpdateLinkCableTransfer  ; Her karede Link veri alışverişini kontrol et

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
; SYSTEM INITIALIZATION (TERMINAL BIOS EKRANI + SGB + LINK)
; =====================================================================
InitSystem:
    ; DMG Renk Paletini Ayarla (Klasik Terminal Kontrastı)
    ld a, %11100100      
    ldh [rBGP], a
    ldh [rOBP0], a
    ldh [rOBP1], a

    xor a
    ldh [rSCX], a
    ldh [rSCY], a

    ; 1. Tilemap'i ($9800) tamamen temizle
    ld hl, $9800
    ld bc, 1024
.clearTerminalMap:
    xor a
    ld [hl], a
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearTerminalMap

    ; 2. Terminal Font / Karakter Setini VRAM'e Yükle ($8000)
    ld hl, $8000    
    ld de, Terminal_FontData
    ld b, 96                ; Karakter set uzunluğu
.copyTermFont:
    ld a, [de]
    ld [hl], a
    inc hl
    inc de
    dec b
    jr nz, .copyTermFont

    ; 3. Terminal Satırlarını Ekrana Yazdır (BIOS / Retro Açılış)
    ld hl, $9822
    ld de, Str_Title
    call PrintTerminalString

    ld hl, $9862
    ld de, Str_Sub
    call PrintTerminalString

    ld hl, $98A2
    ld de, Str_Prompt
    call PrintTerminalString

    ; Başlangıç Durumunu INTRO Yap
    ld a, STATE_INTRO
    ld [CurrentState], a
    ld a, STATE_PLAYING
    ld [PreviousState], a
    ld a, 1
    ld [StarFieldActive], a
    xor a
    ld [PauseCursorPos], a
    ld [LinkConnected], a

    call InitPlanets
    ret

; --- Terminal String Yazdırma Fonksiyonu ---
PrintTerminalString:
.printLoop:
    ld a, [de]
    cp 0                    ; Metin bitti mi?
    ret z
    sub 32                  ; ASCII -> VRAM Tile index dönüşümü
    ld [hl], a              
    inc hl
    inc de
    jr .printLoop

; =====================================================================
; GAME BOY LINK CABLE PROTOCOL RUTİNLERİ
; =====================================================================
InitLinkCable:
    xor a
    ldh [rSB], a            ; Seri tamponunu sıfırla
    ld a, $80               ; $81 = Harici clock (External/Slave), $80 = Dahili clock (Internal/Master)
    ldh [rSC], a            ; Seri kontrol register'ını ayarla
    ret

UpdateLinkCableTransfer:
    ldh a, [rSC]
    bit 7, a                ; Aktarım devam ediyor mu? (Bit 7 = Transfer Start flag)
    jr nz, .transferBusy

    ; Aktarım bittiyse gelen veriyi oku
    ldh a, [rSB]
    ld [LinkDataIn], a
    
    ; Eğer gönderilecek yeni veri varsa hatta sür
    ld a, [LinkDataOut]
    ldh [rSB], a
    
    ; Yeni aktarımı tetikle (Internal Clock / Master Mode)
    ld a, $81
    ldh [rSC], a
    
    ld a, 1
    ld [LinkConnected], a   ; Bağlantı aktif bayrağı
    ret

.transferBusy:
    ret

; =====================================================================
; SUPER GAME BOY (SGB 1 & SGB 2) PROTOKOL RUTİNLERİ
; =====================================================================
InitSGBSupport:
    ld hl, SGB_Packet_MLT_REQ
    call SendSGBPacket
    ret

SGB_Packet_MLT_REQ:
    db ($01 << 3) | 1       
    db $00                  
    ds 14                   

SendSGBPacket:
    ld a, [hl]
    ld c, a                 
    and $07                 
    ret z                   
    ld b, a                 

.packet_loop:
    push bc
    xor a
    ldh [rP1], a
    ld a, $30
    ldh [rP1], a            

    ld c, 16                
.byte_loop:
    ld a, [hl+]             
    ld e, a                 
    ld d, 8                 

.bit_loop:
    srl e                   
    jr c, .send_one         

    ld a, $20               
    ldh [rP1], a
    ld a, $30               
    ldh [rP1], a
    jr .next_bit

.send_one:
    ld a, $10               
    ldh [rP1], a
    ld a, $30               
    ldh [rP1], a

.next_bit:
    dec d
    jr nz, .bit_loop

    dec c
    jr nz, .byte_loop

    ld a, $20               
    ldh [rP1], a
    ld a, $30               
    ldh [rP1], a

    pop bc
    dec b
    jr nz, .packet_loop
    ret

; =====================================================================
; TERMINAL METİNLERİ VE FONT VERİLERİ
; =====================================================================
Str_Title:  db "BGC BLAST LINK", 0
Str_Sub:    db "SGB + LINK MULTIPLAYER", 0
Str_Prompt: db "PRESS START TO PLAY", 0

Terminal_FontData:
    ds 8  ; Space
    db $00,$3C,$42,$42,$7E,$42,$42,$00 ; A
    db $00,$7C,$42,$7C,$42,$42,$7C,$00 ; B
    db $00,$3C,$40,$40,$40,$40,$3C,$00 ; C
    db $00,$7C,$42,$42,$42,$42,$7C,$00 ; D
    db $00,$7E,$40,$7C,$40,$40,$7E,$00 ; E
    db $00,$7E,$40,$7C,$40,$40,$40,$00 ; F
    db $00,$3C,$40,$4E,$42,$42,$3C,$00 ; G
    db $00,$42,$42,$7E,$42,$42,$42,$00 ; H
    db $00,$3C,$18,$18,$18,$18,$3C,$00 ; I
    db $00,$02,$02,$02,$02,$42,$3C,$00 ; J
    db $00,$44,$48,$F0,$48,$44,$42,$00 ; K
    db $00,$40,$40,$40,$40,$40,$7E,$00 ; L
    db $00,$82,$C6,$AA,$92,$82,$82,$00 ; M
    db $00,$42,$62,$52,$4A,$46,$42,$00 ; N
    db $00,$3C,$42,$42,$42,$42,$3C,$00 ; O
    db $00,$7C,$42,$42,$7C,$40,$40,$00 ; P
    db $00,$3C,$42,$42,$4A,$46,$3A,$00 ; Q
    db $00,$7C,$42,$42,$7C,$48,$44,$00 ; R
    db $00,$3C,$40,$3C,$02,$42,$3C,$00 ; S
    db $00,$7E,$18,$18,$18,$18,$18,$00 ; T
    db $00,$42,$42,$42,$42,$42,$3C,$00 ; U
    db $00,$42,$42,$42,$42,$24,$18,$00 ; V
    db $00,$82,$82,$92,$AA,$C6,$82,$00 ; W
    db $00,$42,$24,$18,$18,$24,$42,$00 ; X
    db $00,$42,$42,$24,$18,$18,$18,$00 ; Y
    db $00,$7E,$04,$08,$10,$20,$7E,$00 ; Z
    ds 250

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

WaitVBlank:
    ldh a, [rLY]
    cp 144
    jr nc, WaitVBlank     
.waitV:
    ldh a, [rLY]
    cp 144
    jr c, .waitV          
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
; GAME STATES & LOGIC (INTRO & ARCADE TRANSITION)
; =====================================================================

State_Intro_Logic:
    ld a, [JoypadState]
    bit 3, a            ; Start tuşuna basıldı mı?
    ret z
    
    ; Terminal ekranını tamamen temizle ve Arcade Oyun Motoruna geç!
    ld hl, $9800
    ld bc, 1024
.clearForArcadeGame:
    xor a
    ld [hl], a
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .clearForArcadeGame

    ld a, STATE_PLAYING
    ld [CurrentState], a
    ld [PreviousState], a
    ret

State_MainMenu_Logic:
    ld a, [JoypadState]
    bit 3, a            
    jr nz, .startPlay
    ret
.startPlay:
    ld a, STATE_PLAYING
    ld [CurrentState], a
    ld [PreviousState], a
    ret

State_SkinSelect_Logic:
State_VersusMenu_Logic:
State_GamePaused_Logic:
State_ColorCustomize_Logic:
State_VersusPlaying_Logic:
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
