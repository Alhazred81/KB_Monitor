#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include "config.h"

// ─── SZIRUP ÁLLAPOTOK (ZÖLD - SÁRGA - NARANCS - PIROS - VILLOGÓ PIROS) ───────
enum SyrupState : uint8_t {
    SYRUP_GREEN = 0,         // Normál / Elégséges szint (>50%), rendszer OK
    SYRUP_YELLOW = 1,        // Figyelmeztetés (20-50%), szint csökken
    SYRUP_ORANGE = 2,        // Alacsony (<20%) / Utántöltésre vár / SZTOJ várakozó
    SYRUP_RED = 3,           // Üres (0-5%) / Normál leállítás
    SYRUP_BLINKING_RED = 4   // VÉSZLEÁLLÍTÁS: Szintemelkedési timeout! Szivattyú TILTVA!
};

#define MAX_SYRUP_ENTRIES 10
#define SYRUP_SZTOJ_DURATION_SEC 300 // 5 perc kötelező várakozás ütközés esetén
#define SYRUP_REFILL_TIMEOUT_SEC  60 // 60 mp timeout szintemelkedés elmaradása esetén
#define SYRUP_MIN_RISE_MM          4 // Legalább 4 mm szintemelkedés szükséges a timeout alatt

struct SyrupPairingEntry {
    char monitorId[16];      // Kaptár / Monitor azonosító (pl. "XYZ")
    char tankId[16];         // Párosított sziruptartály (pl. "ABC")
    SyrupState state;        // Aktuális állapot
    bool isAutoPaired;       // Automatikusan összerendelt-e a szerver által
    bool isRefilling;        // Éppen folyamatban van-e a szivattyúzás
    uint32_t refillStartTime; // Szivattyúzás kezdetének időbélyege (millis)
    uint16_t initialDistanceMm; // Kezdeti távolság mm-ben (szintfigyeléshez)
    uint16_t currentDistanceMm; // Legutóbb mért távolság mm-ben
    uint32_t sztojUntilTime; // Időbélyeg (millis), ameddig SZTOJ-ban van
    bool isPumpInterlocked;  // Villogó piros retesz (szivattyúindítás tiltása)
    char errorMessage[48];   // Hiba oka (pl. "Szintemelkedési timeout")
};

// ─── FÜGGVÉNYEK ─────────────────────────────────────────────────────────────
void syrupManagerInit();
void syrupManagerLoop();

// Adagoló monitor utántöltési kérelme (auto-párosítás és ütközéskezelés)
bool syrupRequestRefill(const char* monitorId, const char* preferredTankId = nullptr);

// Szint jelentése a monitortól (távolság mm-ben)
void syrupReportFeederLevel(const char* monitorId, uint16_t distanceMm);

// Szivattyúzás leállítása (kézi vagy automatikus)
void syrupStopRefill(const char* monitorId, bool emergencyTimeout = false, const char* reason = nullptr);

// Vészleállítás / Villogó piros retesz feloldása a gazda által
bool syrupResetInterlock(const char* tankOrMonitorId);

// Lekérdező függvények
SyrupState syrupGetMonitorState(const char* monitorId);
SyrupState syrupGetTankState(const char* tankId);
bool syrupIsPumpAllowed(const char* tankId);
const char* syrupGetPairedTank(const char* monitorId);
bool syrupIsMonitorInSztoj(const char* monitorId, uint32_t* remainingSec = nullptr);

// JSON formátumú állapot a webes felülethez / REST API-hoz
String syrupGetStatusJson();
