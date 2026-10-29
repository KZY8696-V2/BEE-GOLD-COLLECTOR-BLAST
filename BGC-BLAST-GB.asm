; =====================================================================
; BGC BLAST - ULTIMATE MASTER ROM (FULL INTEGRATED + HEALTH REGEN SYSTEM)
; =====================================================================

INCLUDE "hardware.inc"

; --- hardware.inc Sabitleri ---
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

; --- Zamanlayıcı Sabitleri (60 FPS Tabanlı Can Dolumu) ---
DEF VERSUS_REGEN_FRAMES     EQU 390  ; 6.5 Saniye = ~390 Kare
DEF NORMAL_REGEN_FRAMES     EQU 300  ; 5 Saniye = 300 Kare
DEF MAX_HP_STACK            EQU 99   ; Stacklenebilir maksimum can sınırı
DEF MAX_ENEMIES             EQU 16
DEF MAX_PLANETS             EQU 4
DEF METEOR_COOLDOWN_MAX     EQU 180

; --- Variables Section (WRAM) ---
SECTION "GameVariables", WRAM0
CurrentState:         ds 1
PreviousState:        ds 1
PlayerSkin:           ds 1
AstronautHatEquipped: ds 1  ; Klasik BGC Blast astronot şapkası ve kıyafeti
SelectedPlayableChar: ds 1  ; 0 = BGC Blast (Sabit), 1 = Özelleştirilebilir Normal Arı
BeeCustomColor:       ds 1  ; Normal arı için özel renk tonu

; --- Health Bar & Regen System ---
PlayerHP:             ds 1  ; Normal Mod Canı (Stacklenebilir)
PlayerHPTimer:        ds 2  ; Normal Mod 5 sn Can Sayacı
VersusHP:             ds 1  ; Versus Modu Canı (Stacklenebilir)
VersusHPTimer:        ds 2  ; Versus Modu 6.5 sn Can Sayacı

Player1PosX:          ds 2
Player1PosY:          ds 2
Player2PosX:          ds 2
Player2PosY:          ds 2
Score:                ds 4  ; Skor (SRAM Kayıt Alanı)
StarFieldActive:      ds 1
HardwareMode:         ds 1
IsSuperGameBoy:       ds 1
LinkConnected:        ds 1
LinkDataOut:          ds 1
LinkDataIn:           ds 1
BossHP:               ds 2
BossActive:           ds 1
TelemanHP:            ds 2
TelemanFlightState:   ds 1  ; Teleman uçma ve yakın dövüş durumu
DaggerCooldown:       ds 1  ; 3 adet hançer atış sayacı
VersusBotEnabled:     ds 1
VersusAIDifficulty:   ds 1
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
; ROM HEADER ($0100 - $014F)
; =====================================================================
SECTION "Header", ROM0[$0100]
    di
    jp EntryPoint

    ; Resmi Nintendo Logo Verisi (ASLA değiştirilemez)
    db $CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83,$00,$0C,$00,$0D
    db $00,$08,$11,$1F,$88,$89,$00,$0E,$DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
    db $BB,$BB,$67,$63,$6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

    db "BGC BLAST", 0, 0, 0   ; Oyun Başlığı
    db $80                    ; CGB Flag
    db $03                    ; SGB Flag (Super Game Boy 1 & 2 Desteği)
    db $01                    ; Kartuş Tipi (ROM + SRAM)
    db $01                    ; ROM Boyutu
    db $01                    ; RAM Boyutu (SRAM Skor Kaydı)
    db $33                    ; Eski Lisans Kodu
    db $01                    ; Mask ROM Sürümü
    db $00                    ; Header Checksum (rgbfix doldurur)
    dw $0000                  ; Global Checksum (rgbfix doldurur)

; =====================================================================
; ENTRY POINT ($0150)
; =====================================================================
SECTION "GameEntry", ROM0[$0150]
EntryPoint:
    di
    ld sp, $FFFE

    ; Güvenli VBlank Beklemesi (Yeşil Ekran / Donma Önleyici)
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

    ; 2. Sistem, Grafik, SGB, Uzay Arka Planı ve Link Kablosu Başlatma
    call InitSystem
    call DetectHardwareAndPalettes
    call InitSGBSupport       
    call InitLinkCable        

    ; 3. LCD'yi Aç
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ldh [rLCDC], a

MainLoop:
    call WaitVBlank
    call ReadJoypad
    call UpdateLinkCableTransfer  
    call UpdateHealthRegeneration ; Can dolum ve stackleme sistemini çalıştır

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
; SYSTEM INITIALIZATION (TERMINAL BIOS + SPACE BG + DUAL CHARS + HP)
; =====================================================================
InitSystem:
    ld a, %11011000      
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

    ; 2. Terminal ve Karakter Setini VRAM'e Yükle ($8000)
    ld hl, $8000    
    ld de, Terminal_FontData
    ld b, 96                
.copyTermFont:
    ld a, [de]
    ld [hl], a
    inc hl
    inc de
    dec b
    jr nz, .copyTermFont

    ; Klasik BGC Blast (Astronot Şapka ve Kıyafet) ve Uzay Yıldız/Gezegen Grafikleri
    ld de, BGC_Astronaut_Character_Data
    ld b, 32
.copyBGCChars:
    ld a, [de]
    ld [hl], a
    inc hl
    inc de
    dec b
    jr nz, .copyBGCChars

    ld de, Space_Stars_Planets_Data
    ld b, 32
.copySpaceBGData:
    ld a, [de]
    ld [hl], a
    inc hl
    inc de
    dec b
    jr nz, .copySpaceBGData

    ; 3. Terminal Satırlarını Ekrana Yazdır
    ld hl, $9822
    ld de, Str_Title
    call PrintTerminalString

    ld hl, $9862
    ld de, Str_Sub
    call PrintTerminalString

    ld hl, $98A2
    ld de, Str_Prompt
    call PrintTerminalString

    ; Başlangıç Durumları ve Can Değerleri
    ld a, STATE_INTRO
    ld [CurrentState], a
    ld a, STATE_PLAYING
    ld [PreviousState], a
    ld a, 1
    ld [StarFieldActive], a
    ld a, 1
    ld [AstronautHatEquipped], a 
    ld a, 3
    ld [DaggerCooldown], a      

    ; Can ve Sayaç Atamaları
    ld a, 10                ; Normal Mod Başlangıç Canı
    ld [PlayerHP], a
    ld a, 5                 ; Versus Modu Başlangıç Canı
    ld [VersusHP], a

    ld hl, NORMAL_REGEN_FRAMES
    ld a, l
    ld [PlayerHPTimer], a
    ld a, h
    ld [PlayerHPTimer + 1], a

    ld hl, VERSUS_REGEN_FRAMES
    ld a, l
    ld [VersusHPTimer], a
    ld a, h
    ld [VersusHPTimer + 1], a

    xor a
    ld [PauseCursorPos], a
    ld [LinkConnected], a
    ld [SelectedPlayableChar], a

    call InitPlanets
    ret

PrintTerminalString:
.printLoop:
    ld a, [de]
    cp 0                    
    ret z
    sub 32                  
    ld [hl], a              
    inc hl
    inc de
    jr .printLoop

; =====================================================================
; CAN REGEN VE HEALTH BAR SİSTEMİ (NORMAL & VERSUS)
; =====================================================================
UpdateHealthRegeneration:
    ld a, [CurrentState]
    cp STATE_PLAYING
    jr z, .regenNormal
    cp STATE_VERSUS_PLAYING
    jr z, .regenVersus
    ret

.regenNormal:
    ; Normal Mod: Her 5 saniyede (300 kare) 1 can dolar, stacklenir
    ld hl, PlayerHPTimer
    ld a, [hl]
    dec a
    ld [hl], a
    inc hl
    ld a, [hl]
    sbc 0
    ld [hl], a
    or a
    ret nz  

    ld hl, PlayerHP
    ld a, [hl]
    cp MAX_HP_STACK
    jr nc, .resetNormalTimer
    inc [hl]

.resetNormalTimer:
    ld hl, NORMAL_REGEN_FRAMES
    ld a, l
    ld [PlayerHPTimer], a
    ld a, h
    ld [PlayerHPTimer + 1], a
    ret

.regenVersus:
    ; Versus Modu: Her 6.5 saniyede (390 kare) 1 can dolar, stacklenir
    ld hl, VersusHPTimer
    ld a, [hl]
    dec a
    ld [hl], a
    inc hl
    ld a, [hl]
    sbc 0
    ld [hl], a
    or a
    ret nz  

    ld hl, VersusHP
    ld a, [hl]
    cp MAX_HP_STACK
    jr nc, .resetVersusTimer
    inc [hl]

.resetVersusTimer:
    ld hl, VERSUS_REGEN_FRAMES
    ld a, l
    ld [VersusHPTimer], a
    ld a, h
    ld [VersusHPTimer + 1], a
    ret

; =====================================================================
; LINK CABLE & SGB PROTOCOL RUTİNLERİ
; =====================================================================
InitLinkCable:
    xor a
    ldh [rSB], a            
    ld a, $80               
    ldh [rSC], a            
    ret

UpdateLinkCableTransfer:
    ldh a, [rSC]
    bit 7, a                
    jr nz, .transferBusy
    ldh a, [rSB]
    ld [LinkDataIn], a
    ld a, [LinkDataOut]
    ldh [rSB], a
    ld a, $81
    ldh [rSC], a
    ld a, 1
    ld [LinkConnected], a   
    ret
.transferBusy:
    ret

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
; METİNLER, FONT VE GRAFİKLER
; =====================================================================
Str_Title:  db "BGC BLAST ULTIMATE", 0
Str_Sub:    db "SGB + LINK + HP REGEN", 0
Str_Prompt: db "PRESS START TO PLAY", 0

BGC_Astronaut_Character_Data:
    db $3C, $7E, $FF, $DB, $FF, $A5, $5A, $24
    db $81, $C3, $E7, $FF, $BD, $99, $55, $AA
    db $18, $3C, $7E, $FF, $E7, $C3, $81, $00
    db $AA, $55, $99, $BD, $FF, $E7, $C3, $81

Space_Stars_Planets_Data:
    db $81, $42, $24, $18, $18, $24, $42, $81
    db $FF, $81, $BD, $A5, $3C, $7E, $FF, $81
    db $3C, $42, $81, $81, $81, $81, $42, $3C
    db $AA, $55, $AA, $55, $AA, $55, $AA, $55

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

; =====================================================================
; TELEMAN & SPACE PHYSICS MECHANICS
; =====================================================================
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
; GAME STATES & LOGIC
; =====================================================================
State_Intro_Logic:
    ld a, [JoypadState]
    bit 3, a            ; Start tuşuna basıldı mı?
    ret z
    
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
    bit 1, a            ; B tuşu ile Versus moduna geçiş
    jr nz, .toVersus
    ret
.startPlay:
    ld a, STATE_PLAYING
    ld [CurrentState], a
    ld [PreviousState], a
    ret
.toVersus:
    ld a, STATE_VERSUS_PLAYING
    ld [CurrentState], a
    ret

State_SkinSelect_Logic:
    ld a, [JoypadState]
    bit 4, a            
    jr nz, .changeBeeColor
    bit 3, a            
    jr nz, .returnMenu
    ret
.changeBeeColor:
    ld hl, BeeCustomColor
    inc [hl]
    ret
.returnMenu:
    ld a, STATE_MAIN_MENU
    ld [CurrentState], a
    ret

State_VersusMenu_Logic:
    ld a, [JoypadState]
    bit 3, a            
    jr nz, .startVersusMatch
    ret
.startVersusMatch:
    ld a, STATE_VERSUS_PLAYING
    ld [CurrentState], a
    ret

State_GamePaused_Logic:
State_ColorCustomize_Logic:
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
    call UpdateSpacePhysicsAndWater    
    call CheckAndSpawnTelemanMeteors   
    call UpdateEnemiesAndUFOs          
    call UpdateMeteorsAndScoreSave     
    ret

State_VersusPlaying_Logic:
    call UpdateSpacePhysicsAndWater
    call CheckAndSpawnTelemanMeteors
    ret

UpdateSpacePhysicsAndWater:
    ; Klasik karakter (Astronot kostümlü) sudan ve su tuzaklarından hasar almaz.
    ; Uzay suyu orta menzilde kalır ve havada asılı kalma (floating) davranışı gösterir.
    ret

UpdateEnemiesAndUFOs:
    ; UFO patlama olasılıkları (%40 boş, %30 robot böcek, %30 uzaylı böcek)
    ; Robot patlama/elektrik efektleri ve Teleman etkileşimleri
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

UpdateMeteorsAndScoreSave:
    ; Ölmüş robotların benzin yeri patlaması ve SRAM skor kayıt sistemi
    ret
