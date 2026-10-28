#include <gb/gb.h>
#include <stdio.h>

/* --- Game States --- */
#define STATE_MAIN_MENU         0
#define STATE_PLAYING           1
#define STATE_PAUSED            2
#define STATE_SKIN_SELECT       3
#define STATE_VERSUS_MENU       4
#define STATE_VERSUS_PLAYING    5

/* --- AI Difficulties --- */
#define AI_EASY                 1
#define AI_MEDIUM               2
#define AI_HARD                 3
#define AI_EXPERT               4

/* --- Enemy Types --- */
#define ENEMY_TYPE_ALIEN_BUG    1   /* Uzaylı Böcek (Canlı Yeşil Piksel Art) */
#define ENEMY_TYPE_ROBO_BUG     2   /* Robot Böcek (Simsiyah Piksel Art) */
#define ENEMY_TYPE_UFO          3   /* Agresif UFO (Simsiyah Piksel Art) */
#define ENEMY_TYPE_BOSS_TELEMAN 4   /* Patron Teleman (Simsiyah Piksel Art) */

/* --- Boss States --- */
#define BOSS_STATE_IDLE         0
#define BOSS_STATE_PULLING      1
#define BOSS_STATE_THROWING     2

/* --- Game Constants --- */
#define MAX_PLAYER_HP           100
#define VERSUS_REGEN_INTERVAL   300  /* 5 Saniye (60Hz * 5 frame) */
#define VERSUS_REGEN_AMOUNT     5
#define MAX_ENEMIES             16

/* --- Enemy Structure Offsets --- */
#define ENEMY_ACTIVE            0
#define ENEMY_TYPE              1
#define ENEMY_X_POS             2
#define ENEMY_Y_POS             4
#define ENEMY_X_SPEED           6

/* --- Game Variables --- */
UINT8 CurrentState = STATE_MAIN_MENU;
UINT8 PlayerSkin = 0;             
UINT8 AstronautHatEquipped = 0;   
UINT16 Player1PosX = 16;
UINT16 Player1PosY = 80;
UINT16 Player2PosX = 136;
UINT16 Player2PosY = 80;
UINT16 Player1HP = 100;
UINT16 Player2HP = 100;
UINT32 Score = 0;

/* --- Donanım Modu --- */
UINT8 HardwareMode = 0;           

/* --- Boss & Versus Variables --- */
UINT16 BossHP = 800;
UINT8 BossState = BOSS_STATE_IDLE;
UINT8 VersusBotEnabled = 1;
UINT8 VersusAIDifficulty = AI_MEDIUM;   /* Sadece Versus Moduna Özel Zorluk */
UINT8 NormalModeAILevel = AI_MEDIUM;    /* Normal/Savaş Modu Sabit Medium */
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
void DetectHardwareAndSetPalettes(void);
void State_MainMenu_Logic(void);
void State_GamePlaying_Logic(void);
void State_GamePaused_Logic(void);
void State_SkinSelect_Logic(void);
void State_VersusMenu_Logic(void);
void State_VersusPlaying_Logic(void);
void UpdateVersusBotAI(void);
void UpdateNormalModeEnemies(void);
void UpdateVersusHealthRegen(void);
void ProcessUFODestruction(UBYTE *enemyPtr);
void SpawnEnemyAtCoords(UINT8 type, UINT16 x, UINT16 y);
void UpdateBossTeleman(void);

void main(void) {
    InitSystem();
    DetectHardwareAndSetPalettes(); 

    while(1) {
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
        }
        wait_vbl_done();
    }
}

void InitSystem(void) {
    DISPLAY_ON;
    SHOW_CANVAS;
}

/* =====================================================================
 * DONANIM ALGILAMA VE RENK KURALLARI 
 * ===================================================================== */
void DetectHardwareAndSetPalettes(void) {
    if (_cpu == GB_CPU_CGB) {
        HardwareMode = 1; // Renkli GBC/GBA Modu (Yeşil böcekler, siyah robotlar/UFO/patron)
    } else {
        HardwareMode = 0; // Saf DMG Monokrom Modu
        BURST_BGP(0xE4); 
        BURST_OBP0(0xE4); // Uzaylı Böcekler -> Yeşil Ton
        BURST_OBP1(0x1B); // Robotlar, UFO, Patron -> Simsiyah
    }
}

/* =====================================================================
 * 1. MAIN MENU
 * ===================================================================== */
void State_MainMenu_Logic(void) {
    UINT8 joy = joypad();

    if (joy & J_START) {
        CurrentState = STATE_PLAYING;
    } else if (joy & J_SELECT) {
        CurrentState = STATE_VERSUS_MENU;
    } else if (joy & J_A) {
        CurrentState = STATE_SKIN_SELECT;
    }
}

/* =====================================================================
 * 2. VERSUS MENU (Zorluk Seçimi Sadece Burada Aktif)
 * ===================================================================== */
void State_VersusMenu_Logic(void) {
    UINT8 joy = joypad();

    /* Versus Modunda Bot Zorluğunu Ayarlama (Yukarı / Aşağı) */
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
 * 3. VERSUS PLAYING STATE (5 Saniyede Can Artışı & Seçilen Versus Bot AI)
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
    /* Versus moduna özel seçilen zorluk (Easy, Medium, Hard, Expert) */
    if (VersusAIDifficulty == AI_EXPERT) {
        if (Player1PosX > Player2PosX) Player2PosX += 2;
        else if (Player1PosX < Player2PosX) Player2PosX -= 2;
    } else if (VersusAIDifficulty >= AI_HARD) {
        if (Player1PosX > Player2PosX) Player2PosX += 1;
        else if (Player1PosX < Player2PosX) Player2PosX -= 1;
    }
}

/* =====================================================================
 * 4. STANDARD / BATTLE GAMEPLAY (Normal Mod Sabit Medium Seviye)
 * ===================================================================== */
void State_GamePlaying_Logic(void) {
    UINT8 joy = joypad();

    if (joy & J_START) {
        CurrentState = STATE_PAUSED;
        return;
    }

    UpdateNormalModeEnemies();
    UpdateBossTeleman();
}

void UpdateNormalModeEnemies(void) {
    /* Normal savaş modunda yapay zeka/düşmanlar sabit Medium seviyesinde çalışır */
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

void ProcessUFODestruction(UBYTE *enemyPtr) {
    UINT16 rng = GetRandomNumber() % 100;
    UINT16 x = *(UINT16 *)(enemyPtr + ENEMY_X_POS);
    UINT16 y = *(UINT16 *)(enemyPtr + ENEMY_Y_POS);

    *(enemyPtr + ENEMY_ACTIVE) = 0;

    if (rng < 35) {
        SpawnEnemyAtCoords(ENEMY_TYPE_ALIEN_BUG, x, y); // Yeşil Böcek
    } else if (rng < 70) {
        SpawnEnemyAtCoords(ENEMY_TYPE_ROBO_BUG, x, y);  // Siyah Robot Böcek
    } else if (rng < 85) {
        Score += 300;
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

void UpdateBossTeleman(void) {
    if (BossHP == 0) return;

    switch (BossState) {
        case BOSS_STATE_IDLE:
            BossState = BOSS_STATE_PULLING;
            break;
        case BOSS_STATE_PULLING:
            BossState = BOSS_STATE_THROWING;
            break;
        case BOSS_STATE_THROWING:
            BossState = BOSS_STATE_IDLE;
            break;
    }
}

void State_GamePaused_Logic(void) {
    UINT8 joy = joypad();
    if (joy & J_START) CurrentState = STATE_PLAYING;
    else if (joy & J_SELECT) CurrentState = STATE_MAIN_MENU;
}

void State_SkinSelect_Logic(void) {
    UINT8 joy = joypad();
    if (joy & J_A) PlayerSkin = !PlayerSkin;
    else if (joy & J_START) CurrentState = STATE_MAIN_MENU;
}
