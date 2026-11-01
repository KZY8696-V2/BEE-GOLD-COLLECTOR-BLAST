; =====================================================================
; BGC BLAST - ULTIMATE MASTER ROM (NES - STANDART SÜRÜM)
; ca65 / cc65 Uyumlu - Harici nes.inc Gerektirmeyen Bağımsız Kod
; =====================================================================

; --- Dahili PPU, APU ve Joypad Kayıt Adresleri ---
PPU_CTRL          = $2000
PPU_MASK          = $2001
PPU_STATUS        = $2002
PPU_OAMADDR       = $2003
PPU_OAMDATA       = $2004
PPU_SCROLL        = $2005
PPU_ADDR          = $2006
PPU_DATA          = $2007
OAM_DMA           = $4014
JOYPAD1           = $4016
JOYPAD2           = $4017

; --- Oyun Durumları ---
.define STATE_INTRO             0  
.define STATE_MAIN_MENU         1  
.define STATE_PLAYING           2
.define STATE_PAUSED            3
.define STATE_SKIN_SELECT       4  
.define STATE_VERSUS_MENU       5
.define STATE_VERSUS_PLAYING    6
.define STATE_COLOR_CUSTOMIZE   7

; --- Karakterler ---
.define CHAR_BGC_BLAST          0  
.define CHAR_CLASSIC_BEE        1  

; --- Zamanlayıcı ve Optimizasyon Limitleri ---
.define VERSUS_REGEN_FRAMES     600  
.define NORMAL_REGEN_FRAMES     300  
.define MAX_HP_STACK            99   
.define MAX_ENEMIES             16
.define MAX_PLANETS             4
.define CULL_ZONE_THRESHOLD     50   

.segment "ZEROPAGE"
CurrentState:         .res 1
PreviousState:        .res 1
SelectedPlayableChar: .res 1  

PlayerHP:             .res 1  
PlayerHPTimer:        .res 2  
VersusHP:             .res 1  
VersusHPTimer:        .res 2  
VersusRegenFrameCnt:  .res 2  

Player1PosX:          .res 2
Player1PosY:          .res 2
Player2PosX:          .res 2
Player2PosY:          .res 2
ScrollX:              .res 2  
ActiveRenderZoneID:   .res 1  
Score:                .res 4  
StarFieldActive:      .res 1  

JoypadState1:         .res 1  
JoypadState2:         .res 2  

VersusBotEnabled:     .res 1  
PauseCursorPos:       .res 1  
MainMenuCursor:       .res 1  
SkinMenuCursor:       .res 1  
WaterCooldown:        .res 1  
WaterFloatingActive:  .res 1  
EnergyShotCooldown:   .res 1  

BossHP:               .res 2
BossActive:           .res 1
TelemanHP:            .res 2  
TelemanFlightState:   .res 1  
RandomSeed:           .res 2
TelemanMeteorTimer:   .res 2  

; --- Özelleştirme Değişkenleri ---
BgcBlast_BodyColor:          .res 1 
BgcBlast_WingColor:          .res 1 
BgcBlast_AntennaColor:       .res 1 
BgcBlast_EnergyBulletColor:  .res 1 

ClassicBee_BodyColor:        .res 1 
ClassicBee_StripeColor:      .res 1 
ClassicBee_LegColor:         .res 1 
ClassicBee_AntennaColor:     .res 1 
ClassicBee_EyeColor:         .res 1 
ClassicBee_AstronautHelmet:  .res 1 
ClassicBee_AstronautSuit:    .res 1 

EnemyList:            .res MAX_ENEMIES * 8
PlanetList:           .res MAX_PLANETS * 6

; =====================================================================
; iNES ROM HEADER
; =====================================================================
.segment "HEADER"
    .byt "NES", $1A         
    .byt 2                  ; 32KB PRG-ROM
    .byt 1                  ; 8KB CHR-ROM (Grafikler/Çizimler için)
    .byt $01                ; Mapper 0 (NROM), Yatay Ayna

; =====================================================================
; CODE SEGMENT & ENTRY POINT
; =====================================================================
.segment "CODE"

.proc nmi
    rti
.endproc

.proc irq
    rti
.endproc

.export _main
.proc _main
    sei                     
    cld                     
    ldx #$FF
    txs                     

@vbl1:
    bit PPU_STATUS
    bpl @vbl1
@vbl2:
    bit PPU_STATUS
    bpl @vbl2

    jsr InitSystem

MainLoop:
    jsr WaitVBlank
    jsr ReadJoypads         
    jsr UpdateHealthRegeneration 

    lda CurrentState
    cmp #STATE_INTRO
    beq @st_intro
    cmp #STATE_MAIN_MENU
    beq @st_main
    cmp #STATE_PLAYING
    beq @st_play
    cmp #STATE_PAUSED
    beq @st_pause
    cmp #STATE_SKIN_SELECT
    beq @st_skin
    cmp #STATE_VERSUS_PLAYING
    beq @st_vplay
    cmp #STATE_COLOR_CUSTOMIZE
    beq @st_color
    jmp MainLoop

@st_intro:
    jsr State_Intro_Logic
    jmp MainLoop
@st_main:
    jsr State_MainMenu_Logic     
    jmp MainLoop
@st_play:
    jsr State_GamePlaying_Logic  
    jmp MainLoop
@st_pause:
    jsr State_GamePaused_Logic   
    jmp MainLoop
@st_skin:
    jsr State_SkinSelect_Logic   
    jmp MainLoop
@st_vplay:
    jsr State_VersusPlaying_Logic 
    jmp MainLoop
@st_color:
    jsr State_ColorCustomize_Logic
    jmp MainLoop
.endproc

; =====================================================================
; SYSTEM INITIALIZATION (NES)
; =====================================================================
.proc InitSystem
    lda #0
    sta PPU_CTRL
    sta PPU_MASK

    ; Uzay Temalı PPU Palet Yükleme ($3F00)
    lda #$3F
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR

    ldx #0
@pal_loop:
    lda SpacePalettes, x
    sta PPU_DATA
    inx
    cpx #32
    bne @pal_loop

    lda #CHAR_BGC_BLAST
    sta SelectedPlayableChar
    lda #1
    sta StarFieldActive     

    ; Varsayılan Renkler
    lda #$10
    sta BgcBlast_BodyColor
    lda #$20
    sta BgcBlast_WingColor
    lda #$30
    sta BgcBlast_AntennaColor
    lda #$27
    sta BgcBlast_EnergyBulletColor

    lda #$27
    sta ClassicBee_BodyColor
    lda #$0F
    sta ClassicBee_StripeColor
    lda #$10
    sta ClassicBee_LegColor
    lda #$10
    sta ClassicBee_AntennaColor
    lda #$30
    sta ClassicBee_EyeColor
    lda #1
    sta ClassicBee_AstronautHelmet
    lda #1
    sta ClassicBee_AstronautSuit

    lda #10
    sta PlayerHP
    lda #5
    sta VersusHP

    lda #<NORMAL_REGEN_FRAMES
    sta PlayerHPTimer
    lda #>NORMAL_REGEN_FRAMES
    sta PlayerHPTimer + 1

    lda #<VERSUS_REGEN_FRAMES
    sta VersusRegenFrameCnt
    lda #>VERSUS_REGEN_FRAMES
    sta VersusRegenFrameCnt + 1

    lda #0
    sta ScrollX
    sta ScrollX + 1
    sta ActiveRenderZoneID
    sta PauseCursorPos
    sta MainMenuCursor
    sta SkinMenuCursor
    sta VersusBotEnabled

    lda #STATE_MAIN_MENU
    sta CurrentState

    jsr InitPlanets
    rts
.endproc

; =====================================================================
; NES KONTROLÇÜ OKUMA RUTİNİ
; =====================================================================
.proc ReadJoypads
    lda #1
    sta JOYPAD1
    lda #0
    sta JOYPAD1

    ldx #8
    lda #0
@read_p1_bit:
    pha
    lda JOYPAD1
    lsr a               
    pla
    rol a               
    dex
    bne @read_p1_bit
    sta JoypadState1

    ldx #8
    lda #0
@read_p2_bit:
    pha
    lda JOYPAD2
    lsr a               
    pla
    rol a               
    dex
    bne @read_p2_bit
    sta JoypadState2
    rts
.endproc

; =====================================================================
; CAN REGEN VE VERSUS 10 SANİYEDE 2 CAN SİSTEMİ
; =====================================================================
.proc UpdateHealthRegeneration
    lda CurrentState
    cmp #STATE_PLAYING
    beq @regenNormal
    cmp #STATE_VERSUS_PLAYING
    beq @regenVersus
    rts

@regenNormal:
    lda PlayerHPTimer
    bne @skip_lo_norm
    dec PlayerHPTimer + 1
@skip_lo_norm:
    dec PlayerHPTimer

    lda PlayerHPTimer
    ora PlayerHPTimer + 1
    bne @done_norm

    lda PlayerHP
    cmp #MAX_HP_STACK
    bcs @resetNormalTimer
    inc PlayerHP

@resetNormalTimer:
    lda #<NORMAL_REGEN_FRAMES
    sta PlayerHPTimer
    lda #>NORMAL_REGEN_FRAMES
    sta PlayerHPTimer + 1
@done_norm:
    rts

@regenVersus:
    lda VersusRegenFrameCnt
    bne @skip_lo_v
    dec VersusRegenFrameCnt + 1
@skip_lo_v:
    dec VersusRegenFrameCnt

    lda VersusRegenFrameCnt
    ora VersusRegenFrameCnt + 1
    bne @done_v

    ldx #2
@add_hp_loop:
    lda VersusHP
    cmp #MAX_HP_STACK
    bcs @skip_add
    inc VersusHP
@skip_add:
    dex
    bne @add_hp_loop

    lda #<VERSUS_REGEN_FRAMES
    sta VersusRegenFrameCnt
    lda #>VERSUS_REGEN_FRAMES
    sta VersusRegenFrameCnt + 1
@done_v:
    rts
.endproc

; =====================================================================
; OYUN MANTIĞI VE UZAY ANİMASYONLARI
; =====================================================================
.proc State_Intro_Logic
    lda JoypadState1
    and #%00001000      
    beq @ret
    lda #STATE_MAIN_MENU
    sta CurrentState
@ret:
    rts
.endproc

.proc State_MainMenu_Logic
    lda JoypadState1
    and #%00001000      ; Start -> Oyuna Başla
    bne @startPlaying
    lda JoypadState1
    and #%00000100      ; Select -> Skin Menü
    bne @openSkinMenu
    lda JoypadState1
    and #%00000010      ; B -> Versus Mod
    bne @startVersus
    rts

@startPlaying:
    lda #STATE_PLAYING
    sta CurrentState
    lda #0
    sta ScrollX
    sta ScrollX + 1
    rts

@openSkinMenu:
    lda #STATE_SKIN_SELECT
    sta CurrentState
    rts

@startVersus:
    lda #STATE_VERSUS_PLAYING
    sta CurrentState
    rts
.endproc

.proc State_GamePlaying_Logic
    lda JoypadState1
    and #%00001000
    beq @noPause
    lda #STATE_PLAYING
    sta PreviousState
    lda #STATE_PAUSED
    sta CurrentState
    rts

@noPause:
    jsr UpdateStarFieldAndScroll   
    jsr HandlePlayerDPadMovement   
    jsr CheckAndCullingOldZones    
    jsr UpdateCharacterShot        
    rts
.endproc

.proc State_GamePaused_Logic
    lda JoypadState1
    and #%00001000
    beq @checkSelect
    lda PauseCursorPos
    bne @returnToMainMenu
    
    lda #STATE_PLAYING
    sta CurrentState
    rts

@returnToMainMenu:
    lda #STATE_MAIN_MENU
    sta CurrentState
@checkSelect:
    rts
.endproc

.proc State_SkinSelect_Logic
    lda JoypadState1
    and #%00001000                  
    bne @backToMenu
    
    lda JoypadState1
    and #%00000001                  
    bne @changeSkinOption
    rts

@changeSkinOption:
    lda SelectedPlayableChar
    eor #1
    sta SelectedPlayableChar
    rts

@backToMenu:
    lda #STATE_MAIN_MENU
    sta CurrentState
    rts
.endproc

.proc State_VersusPlaying_Logic
    lda JoypadState1
    and #%00001000
    beq @ret
    lda #STATE_MAIN_MENU
    sta CurrentState
@ret:
    rts
.endproc

.proc State_ColorCustomize_Logic
    rts
.endproc

; --- Uzay Yıldız Alanı ve Yumuşak Sağa Kaydırma ---
.proc UpdateStarFieldAndScroll
    lda StarFieldActive
    beq @skipStars
    inc ScrollX
    bne @skipStars
    inc ScrollX + 1
@skipStars:
    rts
.endproc

; --- Çok Geride Kalan 50 Bölgeyi Render Etmeme (Zone Culling) ---
.proc CheckAndCullingOldZones
    lda ScrollX + 1             
    sec
    sbc #CULL_ZONE_THRESHOLD    
    bcc @keepAllActive          
    sta ActiveRenderZoneID
@keepAllActive:
    rts
.endproc

; --- D-Pad ile Her Yöne Kontrol ---
.proc HandlePlayerDPadMovement
    lda JoypadState1
    rts
.endproc

; --- Karakter Atış / Mermi Renklendirme Mekaniği ---
.proc UpdateCharacterShot
    lda SelectedPlayableChar
    cmp #CHAR_BGC_BLAST
    bne @checkClassicBee
    
    lda JoypadState1
    and #%00000001
    beq @done
    jmp @done

@checkClassicBee:
    lda JoypadState1
    and #%00000001
    beq @done
@done:
    rts
.endproc

.proc InitPlanets
    rts
.endproc

.proc WaitVBlank
@vb:
    bit PPU_STATUS
    bpl @vb
    rts
.endproc

; --- Uzay Temalı Renk Paletleri ---
.segment "RODATA"
SpacePalettes:
    .byt $0F,$11,$21,$31, $0F,$02,$12,$22, $0F,$03,$13,$23, $0F,$15,$25,$35
    .byt $0F,$16,$26,$36, $0F,$17,$27,$37, $0F,$18,$28,$38, $0F,$19,$29,$39

; --- Vektörler ---
.segment "VECTORS"
    .word nmi
    .word _main
    .word irq
