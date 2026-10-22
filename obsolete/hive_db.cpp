#include "hive_db.h"
#include <LittleFS.h>

HiveProfile gHives[MAX_HIVES];
int gHiveCount = 0;
sqlite3 *db = nullptr;

static int dbCallback(void *data, int argc, char **argv, char **azColName) {
    return 0;
}

int executeSQL(const char *sql) {
    char *zErrMsg = 0;
    int rc = sqlite3_exec(db, sql, dbCallback, 0, &zErrMsg);
    if (rc != SQLITE_OK) {
        Serial.printf("[SQL HIBA] %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
    }
    return rc;
}

bool hiveDbInit() {
    Serial.println("[HIVEDB] SQLite inicializálása...");
    sqlite3_initialize();
    
    // A feltöltött adatbázis megnyitása
    if (sqlite3_open("/littlefs/hive_db.db", &db)) {
        Serial.printf("[HIVEDB] Hiba az adatbázis megnyitásakor: %s\n", sqlite3_errmsg(db));
        return false;
    }
    Serial.println("[HIVEDB] Adatbázis sikeresen megnyitva!");
    
    // Induláskor azonnal feltölti a memóriát az SQL adatokkal
    return hiveDbLoad();
}

void hiveDbClose() {
    if (db) {
        sqlite3_close(db);
        Serial.println("[HIVEDB] Adatbázis lezárva.");
    }
}

bool hiveDbLoad() {
    gHiveCount = 0;
    
    // Kaptár és Biológia (anya) adatok összekötése SQL szinten
    const char* sql = 
        "SELECT h.id, h.monitor_id, h.layout, h.pollen_active, h.lat, h.lon, "
        "c.queen_year, c.queen_origin, c.origin_type, c.function "
        "FROM hives h LEFT JOIN colonies c ON h.colony_id = c.id;";
        
    sqlite3_stmt *res;
    if (sqlite3_prepare_v2(db, sql, -1, &res, 0) != SQLITE_OK) {
        Serial.println("[HIVEDB] Lekérdezési hiba (vagy meg nincs letrehozva a tablak szerkezete)!");
        return false;
    }
    
    while (sqlite3_step(res) == SQLITE_ROW) {
        if (gHiveCount >= MAX_HIVES) break;
        
        HiveProfile& hp = gHives[gHiveCount];
        hp.id = sqlite3_column_text(res, 0) ? (const char*)sqlite3_column_text(res, 0) : "";
        hp.monitorId = sqlite3_column_int(res, 1);
        hp.boxLayout = sqlite3_column_text(res, 2) ? (const char*)sqlite3_column_text(res, 2) : "";
        hp.pollenActive = sqlite3_column_int(res, 3) > 0;
        hp.lat = sqlite3_column_double(res, 4);
        hp.lon = sqlite3_column_double(res, 5);
        hp.queenYear = sqlite3_column_int(res, 6);
        hp.queenOrigin = sqlite3_column_text(res, 7) ? (const char*)sqlite3_column_text(res, 7) : "";
        hp.originType = sqlite3_column_text(res, 8) ? (const char*)sqlite3_column_text(res, 8) : "";
        hp.function = sqlite3_column_text(res, 9) ? (const char*)sqlite3_column_text(res, 9) : "";
        
        gHiveCount++;
    }
    sqlite3_finalize(res);
    Serial.printf("[HIVEDB] Betöltve %d kaptár az SQLite adatbázisból.\n", gHiveCount);
    return true;
}

bool hiveDbAdd(const HiveProfile& hive) {
    // Új kaptár mentése SQLite-ba
    String colonyId = "C-" + String(hive.queenYear) + "-" + String(millis());
    String sqlCol = "INSERT INTO colonies (id, queen_year, queen_origin, origin_type, function) VALUES ('" + 
                    colonyId + "', " + String(hive.queenYear) + ", '" + hive.queenOrigin + "', '" + 
                    hive.originType + "', '" + hive.function + "');";
    executeSQL(sqlCol.c_str());

    String sqlHive = "INSERT OR REPLACE INTO hives (id, monitor_id, colony_id, lat, lon, layout, pollen_active) VALUES ('" +
                     hive.id + "', " + String(hive.monitorId) + ", '" + colonyId + "', " + 
                     String(hive.lat) + ", " + String(hive.lon) + ", '" + hive.boxLayout + "', 1);";
    executeSQL(sqlHive.c_str());
    
    return hiveDbLoad();
}

bool hiveDbSave() {
    // A memóriatömböt nem kell külön kimenteni, mert az SQLite minden műveletnél azonnal ír a flash-re.
    // Ez a függvény csak a korábbi kód kompatibilitása miatt maradt meg.
    return true;
}

HiveProfile* hiveDbGet(const String& id) {
    for (int i = 0; i < gHiveCount; i++) {
        if (gHives[i].id == id) return &gHives[i];
    }
    return nullptr;
}