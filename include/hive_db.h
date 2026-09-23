#pragma once
#include <Arduino.h>
#include <sqlite3.h>

#define MAX_HIVES 100  

struct HiveProfile {
    String id;
    uint8_t monitorId;
    String nfcTag;         // A korábbi baseBoxId helyett
    String queenId;
    String queenOrigin;
    int queenYear;
    String originType;
    String function;
    float lat;
    float lon;
    int honeySupers;
    int broodBoxes;
    String boxLayout;
    bool pollenActive;
};

extern HiveProfile gHives[MAX_HIVES];
extern int gHiveCount;
extern sqlite3 *db;

bool hiveDbInit();
bool hiveDbLoad();
bool hiveDbSave();
bool hiveDbAdd(const HiveProfile& hive);
HiveProfile* hiveDbGet(const String& id);
void hiveDbClose();
int executeSQL(const char *sql);