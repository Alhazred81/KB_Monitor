#include "hive_db.h"
#include <LittleFS.h>
#include <ArduinoJson.h>

HiveProfile gHives[MAX_HIVES];
int gHiveCount = 0;

void hiveDbInit() {
    gHiveCount = 0;
}

bool hiveDbLoad() {
    if (!LittleFS.exists("/hives.json")) {
        Serial.println("[DB] A hives.json nem létezik.");
        return false;
    }

    File file = LittleFS.open("/hives.json", "r");
    if (!file) {
        Serial.println("[DB] Nem sikerült megnyitni a hives.json fájlt olvasásra.");
        return false;
    }

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, file);
    file.close();

    if (error) {
        Serial.print("[DB] JSON parse hiba: ");
        Serial.println(error.c_str());
        return false;
    }

    gHiveCount = 0;
    JsonArray array = doc.as<JsonArray>();
    for (JsonObject obj : array) {
        if (gHiveCount >= MAX_HIVES) break;
        
        gHives[gHiveCount].id          = obj["id"].as<String>();
        gHives[gHiveCount].monitorId   = obj["monitorId"] | 0;
        gHives[gHiveCount].baseBoxId   = obj["baseBoxId"].as<String>();
        gHives[gHiveCount].queenId     = obj["queenId"].as<String>();
        gHives[gHiveCount].queenOrigin = obj["queenOrigin"].as<String>();
        gHives[gHiveCount].queenYear   = obj["queenYear"] | 2026;
        gHives[gHiveCount].originType  = obj["originType"].as<String>();
        gHives[gHiveCount].function    = obj["function"].as<String>();
        gHives[gHiveCount].lat         = obj["lat"] | 0.0f;
        gHives[gHiveCount].lon         = obj["lon"] | 0.0f;
        gHives[gHiveCount].honeySupers = obj["honeySupers"] | 0;
        gHives[gHiveCount].broodBoxes  = obj["broodBoxes"] | 1;

        gHiveCount++;
    }

    Serial.printf("[DB] Sikeresen betöltve %d kaptár a JSON-ből.\n", gHiveCount);
    return true;
}

bool hiveDbSave() {
    JsonDocument doc;
    JsonArray array = doc.to<JsonArray>();

    for (int i = 0; i < gHiveCount; i++) {
        JsonObject obj = array.add<JsonObject>();
        obj["id"]          = gHives[i].id;
        obj["monitorId"]   = gHives[i].monitorId;
        obj["baseBoxId"]   = gHives[i].baseBoxId;
        obj["queenId"]     = gHives[i].queenId;
        obj["queenOrigin"] = gHives[i].queenOrigin;
        obj["queenYear"]   = gHives[i].queenYear;
        obj["originType"]  = gHives[i].originType;
        obj["function"]    = gHives[i].function;
        obj["lat"]         = gHives[i].lat;
        obj["lon"]         = gHives[i].lon;
        obj["honeySupers"] = gHives[i].honeySupers;
        obj["broodBoxes"]  = gHives[i].broodBoxes;
    }

    File file = LittleFS.open("/hives.json", "w");
    if (!file) {
        Serial.println("[DB] Nem sikerült megnyitni a hives.json fájl írásra.");
        return false;
    }

    serializeJson(doc, file);
    file.close();
    return true;
}

bool hiveDbAdd(const HiveProfile& hive) {
    if (gHiveCount >= MAX_HIVES) return false;
    gHives[gHiveCount++] = hive;
    return hiveDbSave();
}

HiveProfile* hiveDbGet(const String& id) {
    for (int i = 0; i < gHiveCount; i++) {
        if (gHives[i].id == id) {
            return &gHives[i];
        }
    }
    return nullptr;
}