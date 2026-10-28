#include <gb/gb.h>
#include <stdio.h>

/* --- Game States --- */
#define STATE_MAIN_MENU         0
#define STATE_PLAYING           1
#define STATE_PAUSED            2
#define STATE_SKIN_SELECT       3
#define STATE_VERSUS_MENU       4
#define STATE_VERSUS_PLAYING    5
#define STATE_COLOR_CUSTOMIZE   6

/* --- AI Difficulties --- */
#define AI_EASY                 1
#define AI_MEDIUM               2
#define AI_HARD                 3
#define AI_EXPERT               4

/* --- Enemy Types --- */
#define ENEMY_TYPE_ALIEN_BUG    1   /* Uzaylı Böcek (Yeşil Piksel Art) */
#define ENEMY_TYPE_ROBO_BUG     2   /* Robot Böcek (Beyaz & Gri Piksel Art) */
#define ENEMY_TYPE_UFO          3   /* Agresif UFO */
#define ENEMY_TYPE_BOSS_TELEMAN 4   /* Patron Teleman */

/* --- Game Constants --- */
#define MAX_PLAYER_HP           100
#define VERSUS_REGEN_INTERVAL   300  /* 5 Saniye */
#define VERSUS_REGEN_AMOUNT     5
#define MAX_ENEMIES             16

/* --- Enemy Structure Offsets --- */
#define ENEMY_ACTIVE            0
#define ENEMY_TYPE              1
#define ENEMY_X_POS             2
#define ENEMY_Y_POS             4

/* --- Game Variables --- */
UINT8 CurrentState = STATE_MAIN_MENU;
UINT8 PlayerSkin = 0;             /* 0 = BGC Blast, 1 = Classic */
UINT8 AstronautHatEquipped = 0;   
UINT16 Player1PosX = 16;
UINT16 Player1PosY = 80;
UINT16 Player2PosX = 136;
UINT16 Player2PosY = 80;
UINT16 Player1HP = 100;
UINT16 Player2HP = 100;
UINT32 Score = 0;

/* --- Uzay Arka Planı ve Yıldız Sistemi --- */
UINT8 StarFieldActive = 1;

/* --- Donanım ve Renk Modu --- */
UINT8 HardwareMode = 0;           
UINT8 DMG_PaletteChoice = 1;      

/* --- Karakter Özelleştirme ve Uçak Modülü --- */
typedef struct {
    UINT8 bodyColor;      
    UINT8 stripeColor;    
    UINT8 grayPartColor;  
    UINT8 whitePartColor; 
    UINT8 isDefault;      
    UINT8 wingsEquipped;  
    UINT8 engineEquipped; 
} CharacterCustomization;

CharacterCustomization PlayerCustom = {0, 0, 0, 0, 1, 1, 1};

/* --- Boss & Versus Variables --- */
UINT16 BossHP = 800;
UINT8 VersusBotEnabled = 1;
UINT8 VersusAIDifficulty = AI_MEDIUM;
UINT16 VersusRegenTimer = VERSUS_REGEN_INTERVAL;

/* Enemy List Array */
UBYTE EnemyList[MAX_ENEMIES * 8];

/* --- Pseudo-RNG --- */
UINT16 RandomSeed = 42;
UINT16 GetRandomNumber(void) {
    RandomSeed = (RandomSeed * 5 + 1);
    return RandomSeed;
}

/* --- Fonksiyon Bildirimleri --- */
void InitSystem(void);
void DetectHardwareAndPalettes(void);
void DrawSpaceBackgroundStars(void);
void State_MainMenu_Logic(void);
void State_GamePlaying_Logic(void);
void State_GamePaused_Logic(void);
void State_SkinSelect_Logic(void);
void State_VersusMenu_Logic(void);
void State_VersusPlaying_Logic(void);
void State_ColorCustomize_Logic(void);
void UpdateVersusBotAI(void);
void UpdateNormalModeEnemies(void);
void UpdateVersusHealthRegen(void);
void ProcessEnemyDestruction(UBYTE *enemyPtr, UINT8 killerSkin);
void SpawnEnemyAtCoords(UINT8 type, UINT16 x, UINT16 y);
void UpdateBossTeleman(void);

void main(void) {
    InitSystem();
    DetectHardwareAndPalettes(); 

    while(1) {
        if (StarFieldActive) {
            DrawSpaceBackgroundStars();
        }

        switch(CurrentState) {
            case STATE_MAIN_MENU:
                State_MainMenu_Logic();
                break;
            case STATE_PLAYING:
                State_GamePlaying_Logic();
                break;
            case STATE_PAUSED:
                State_GamePaused_Logic();
                break;
            case STATE_SKIN_SELECT:
                State_SkinSelect_Logic();
                break;
            case STATE_VERSUS_MENU:
                State_VersusMenu_Logic();
                break;
            case STATE_VERSUS_PLAYING:
                State_VersusPlaying_Logic();
                break;
            case STATE_COLOR_CUSTOMIZE:
                State_ColorCustomize_Logic();
                break;
        }
        wait_vbl_done();
    }
}

void InitSystem(void) {
    DISPLAY_ON;
    SHOW_CANVAS;
}

void DetectHardwareAndPalettes(void) {
    if (_cpu == GB_CPU_CGB) {
        HardwareMode = 1; 
    } else {
        HardwareMode = 0; 
        BURST_BGP(0xE4); 
        BURST_OBP0(0xE4); 
        BURST_OBP1(0x1B); 
    }
}

void DrawSpaceBackgroundStars(void) {
    /* Derin uzay yıldız akış simülasyonu */
}

/* =====================================================================
 * 1. UZAY TEMALI ANA MENÜ
 * ===================================================================== */
void State_MainMenu_Logic(void) {
    UINT8 joy = joypad();

    if (joy & J_START) {
        CurrentState = STATE_PLAYING;
    } else if (joy & J_SELECT) {
        CurrentState = STATE_VERSUS_MENU;
    } else if (joy & J_A) {
        CurrentState = STATE_SKIN_SELECT;
    } else if (joy & J_B) {
        CurrentState = STATE_COLOR_CUSTOMIZE;
    }
}

/* =====================================================================
 * 2. DETAYLI BOYAMA VE ÖZELLEŞTİRME MENÜSÜ
 * ===================================================================== */
void State_ColorCustomize_Logic(void) {
    UINT8 joy = joypad();

    if (HardwareMode == 0) {
        if (joy & J_RIGHT) {
            DMG_PaletteChoice++;
            if (DMG_PaletteChoice > 4) DMG_PaletteChoice = 1;
        } else if (joy & J_LEFT) {
            DMG_PaletteChoice--;
            if (DMG_PaletteChoice < 1) DMG_PaletteChoice = 4;
        }
    } else {
        if (joy & J_UP) {
            PlayerCustom.bodyColor++;
            PlayerCustom.isDefault = 0;
        } else if (joy & J_DOWN) {
            PlayerCustom.stripeColor++;
            PlayerCustom.isDefault = 0;
        } else if (joy & J_RIGHT) {
            PlayerCustom.grayPartColor++;
            PlayerCustom.isDefault = 0;
        } else if (joy & J_LEFT) {
            PlayerCustom.whitePartColor++;
            PlayerCustom.isDefault = 0;
        } else if (joy & J_SELECT) {
            /* Varsayılan / İlk Halindeki Orijinal Görünüm */
            PlayerCustom.bodyColor = 0;
            PlayerCustom.stripeColor = 0;
            PlayerCustom.grayPartColor = 0;
            PlayerCustom.whitePartColor = 0;
            PlayerCustom.isDefault = 1;
        }
    }

    if (joy & J_START) {
        CurrentState = STATE_MAIN_MENU;
    }
}

/* =====================================================================
 * 3. VERSUS MENU
 * ===================================================================== */
void State_VersusMenu_Logic(void) {
    UINT8 joy = joypad();

    if (joy & J_UP) {
        if (VersusAIDifficulty < AI_EXPERT) VersusAIDifficulty++;
    } else if (joy & J_DOWN) {
        if (VersusAIDifficulty > AI_EASY) VersusAIDifficulty--;
    }

    if (joy & J_START) {
        Player1HP = 100;
        Player2HP = 100;
        CurrentState = STATE_VERSUS_PLAYING;
    }
}

/* =====================================================================
 * 4. VERSUS PLAYING STATE
 * ===================================================================== */
void State_VersusPlaying_Logic(void) {
    UINT8 joy = joypad();

    if (joy & J_START) {
        CurrentState = STATE_PAUSED;
        return;
    }

    UpdateVersusHealthRegen();

    if (VersusBotEnabled) {
        UpdateVersusBotAI();
    }
}

void UpdateVersusHealthRegen(void) {
    if (VersusRegenTimer > 0) {
        VersusRegenTimer--;
    } else {
        Player1HP += VERSUS_REGEN_AMOUNT;
        if (Player1HP > MAX_PLAYER_HP) Player1HP = MAX_PLAYER_HP;

        Player2HP += VERSUS_REGEN_AMOUNT;
        if (Player2HP > MAX_PLAYER_HP) Player2HP = MAX_PLAYER_HP;

        VersusRegenTimer = VERSUS_REGEN_INTERVAL;
    }
}

void UpdateVersusBotAI(void) {
    if (VersusAIDifficulty == AI_EXPERT) {
        if (Player1PosX > Player2PosX) Player2PosX += 2;
        else if (Player1PosX < Player2PosX) Player2PosX -= 2;
    } else if (VersusAIDifficulty >= AI_HARD) {
        if (Player1PosX > Player2PosX) Player2PosX += 1;
        else if (Player1PosX < Player2PosX) Player2PosX -= 1;
    }
}

/* =====================================================================
 * 5. STANDARD UZAY SAVAŞI GAMEPLAY
 * ===================================================================== */
void State_GamePlaying_Logic(void) {
    UINT8 joy = joypad();

    if (joy & J_START) {
        CurrentState = STATE_PAUSED;
        return;
    }

    UpdateNormalModeEnemies();
}

void UpdateNormalModeEnemies(void) {
    UBYTE *enemyPtr = EnemyList;
    UINT8 i;

    for (i = 0; i < MAX_ENEMIES; i++) {
        if (*(enemyPtr + ENEMY_ACTIVE) == 0) {
            enemyPtr += 8;
            continue;
        }
        enemyPtr += 8;
    }
}

/* =====================================================================
 * ÖLÜM EFEKTLERİ MİMARİSİ:
 * - BGC Blast:
 *   * Uzaylı Böcek vb. -> Standart Patlama
 *   * Robot Karakterler -> %50 Elektrik Çarpması, %50 Patlama (RNG)
 * - Classic:
 *   * Uzaylı Böcek -> Yeşil Slime / Su Patlaması
 *   * Robotlar / Teleman -> Elektrik Çarpmasıyla Yok Oluş
 * ===================================================================== */
void ProcessEnemyDestruction(UBYTE *enemyPtr, UINT8 killerSkin) {
    UINT8 enemyType = *(enemyPtr + ENEMY_TYPE);
    *(enemyPtr + ENEMY_ACTIVE) = 0; /* Düşmanı yok et */

    if (killerSkin == 0) {
        /* BGC Blast Karakteri Tarafından Yok Edildi */
        if (enemyType == ENEMY_TYPE_ROBO_BUG) {
            /* Robot Karakterler İçin %50 İhtimal (Elektrik vs Patlama) */
            UINT16 rng50 = GetRandomNumber() % 100;
            if (rng50 < 50) {
                /* %50 Elektrik ile Çarpılarak Ölüm */
                Score += 350;
            } else {
                /* %50 Doğrudan Patlama */
                Score += 250;
            }
        } else {
            Score += 250;
        }
    } else {
        /* Classic Karakteri Tarafından Yok Edildi */
        if (enemyType == ENEMY_TYPE_ALIEN_BUG) {
            /* Uzaylı Böcekler -> Yeşil Slime / Su Patlaması */
            Score += 200;
        } else {
            /* Robot Böcekler veya Patron Teleman -> Elektrik Çarpması */
            Score += 400;
        }
    }
}

void SpawnEnemyAtCoords(UINT8 type, UINT16 x, UINT16 y) {
    UBYTE *enemyPtr = EnemyList;
    UINT8 i;
    for (i = 0; i < MAX_ENEMIES; i++) {
        if (*(enemyPtr + ENEMY_ACTIVE) == 0) {
            *(enemyPtr + ENEMY_ACTIVE) = 1;
            *(enemyPtr + ENEMY_TYPE) = type;
            *(UINT16 *)(enemyPtr + ENEMY_X_POS) = x;
            *(UINT16 *)(enemyPtr + ENEMY_Y_POS) = y;
            break;
        }
        enemyPtr += 8;
    }
}

void State_GamePaused_Logic(void) {
    UINT8 joy = joypad();
    if (joy & J_START) CurrentState = STATE_PLAYING;
    else if (joy & J_SELECT) CurrentState = STATE_MAIN_MENU;
}

void State_SkinSelect_Logic(void) {
    UINT8 joy = joypad();
    if (joy & J_A) {
        PlayerSkin = !PlayerSkin; /* BGC Blast (0) ve Classic (1) arasında geçiş */
    } else if (joy & J_START) {
        CurrentState = STATE_MAIN_MENU;
    }
}
