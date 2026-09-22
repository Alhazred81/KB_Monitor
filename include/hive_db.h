#pragma once
#include <Arduino.h>

#define MAX_HIVES 500

struct HiveProfile {
    String id;             // A kaptár egyedi logikai azonosítója (pl. MAC vagy belső ID)
    uint8_t monitorId;     // A rádiós kaptármonitor (szenzor) azonosítója
    String baseBoxId;      // A beolvasott fészekfiók vonalkódja/QR kódja
    String queenId;        // Anya egyedi azonosítója (ha van rajta számozott lapka)
    String queenOrigin;    // Származás (Saját nevelés, tenyésztő stb.)
    int queenYear;         // Évjárat (szín, pl. 2026)
    String originType;     // Kialakulás (Műraj, Raj stb.)
    String function;       // Funkció (Termelő, Dajka stb.)
    float lat;
    float lon;
    int honeySupers;       // Mézterek száma
    int broodBoxes;        // Fészekfiókok száma
};

extern HiveProfile gHives[MAX_HIVES];
extern int gHiveCount;

void hiveDbInit();
bool hiveDbLoad();
bool hiveDbSave();
bool hiveDbAdd(const HiveProfile& hive);
HiveProfile* hiveDbGet(const String& id);