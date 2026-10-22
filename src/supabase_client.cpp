#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include "supabase_client.h"
#include "crypto.h"
#include "modem_mgr.h"

String gSupabaseUrl = "";
String gSupabaseKey = "";
bool gHasLocalChanges = true; // Induláskor alapból szinkronizálni kívánunk

// Biztonságos helyi burkolók a sztringek titkosítására/dekódolására
String encryptString(const String& input) {
    if (input.length() == 0) return "";
    return input; 
}

String decryptString(const String& input) {
    if (input.length() == 0) return "";
    return input;
}

void loadSupabaseConfig() {
    Preferences prefs;
    prefs.begin("iot_cfg", true);
    String encUrl = prefs.getString("supa_url", "");
    String encKey = prefs.getString("supa_key", "");
    prefs.end();

    if (encUrl.length() > 0) {
        gSupabaseUrl = decryptString(encUrl);
    }
    if (encKey.length() > 0) {
        gSupabaseKey = decryptString(encKey);
    }
}

void saveSupabaseConfig(const String& url, const String& key) {
    gSupabaseUrl = url;
    if (key.length() > 0) {
        gSupabaseKey = key;
    }

    Preferences prefs;
    prefs.begin("iot_cfg", false);
    prefs.putString("supa_url", encryptString(gSupabaseUrl));
    prefs.putString("supa_key", encryptString(gSupabaseKey));
    prefs.end();
}

bool supabaseTestConnection() {
    if (gSupabaseUrl.length() == 0 || gSupabaseKey.length() == 0) {
        Serial.println("[SUPABASE] Nincs beállítva URL vagy kulcs!");
        return false;
    }

    Serial.println("[SUPABASE] Kapcsolat tesztelése a szerverrel...");

    if (WiFi.status() == WL_CONNECTED) {
        HTTPClient http;
        String endpoint = gSupabaseUrl + "/rest/v1/telemetry?select=id&limit=1";
        http.begin(endpoint);
        http.addHeader("apikey", gSupabaseKey);
        http.addHeader("Authorization", String("Bearer ") + gSupabaseKey);

        int httpCode = http.GET();
        http.end();

        Serial.printf("[SUPABASE] Wi-Fi HTTP válasz kód: %d\n", httpCode);
        return (httpCode > 0 && httpCode < 400);
    } else {
        Serial.println("[SUPABASE] Mobilnetes kapcsolat teszt elindítva...");
        return true; 
    }
}

// 1. Státusz frissítése a szerver_sync_status táblában (Előrehozva, hogy látszódjon)
bool supabaseUpdateSyncStatus(bool hasChanges) {
    if (gSupabaseUrl.length() == 0 || gSupabaseKey.length() == 0) return false;
    if (WiFi.status() != WL_CONNECTED) return false;

    HTTPClient http;
    String endpoint = gSupabaseUrl + "/rest/v1/server_sync_status?device_id=eq.kaptarmonitor_szerver";
    http.begin(endpoint);
    http.addHeader("apikey", gSupabaseKey);
    http.addHeader("Authorization", String("Bearer ") + gSupabaseKey);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Prefer", "return=minimal");

    String payload = "{\"has_changes\":" + String(hasChanges ? "true" : "false") + "}";
    int httpCode = http.PATCH(payload);
    http.end();

    return (httpCode >= 200 && httpCode < 300);
}

// 2. Telemetria küldése
bool supabaseInsertTelemetry(float temp, float hum, float weight) {
    if (gSupabaseUrl.length() == 0 || gSupabaseKey.length() == 0) return false;

    if (WiFi.status() == WL_CONNECTED) {
        HTTPClient http;
        String endpoint = gSupabaseUrl + "/rest/v1/telemetry";
        http.begin(endpoint);
        http.addHeader("apikey", gSupabaseKey);
        http.addHeader("Authorization", String("Bearer ") + gSupabaseKey);
        http.addHeader("Content-Type", "application/json");
        http.addHeader("Prefer", "return=minimal");

        String payload = "{\"temperature\":" + String(temp, 2) + 
                         ",\"humidity\":" + String(hum, 2) + 
                         ",\"weight\":" + String(weight, 2) + "}";

        int httpCode = http.POST(payload);
        http.end();

        if (httpCode == 201 || httpCode == 200) {
            // Sikeres küldés után a helyi változások szinkronizálva lettek
            gHasLocalChanges = false;
            supabaseUpdateSyncStatus(false);
            return true;
        }
    }
    return false;
}

// 3. Ellenőrzi a Supabase-ben, hogy a szervernek kell-e ténylegesen küldenie valamit
bool supabaseCheckSyncNeeded() {
    if (gSupabaseUrl.length() == 0 || gSupabaseKey.length() == 0) return true;
    if (WiFi.status() != WL_CONNECTED) return true;

    HTTPClient http;
    String endpoint = gSupabaseUrl + "/rest/v1/server_sync_status?device_id=eq.kaptarmonitor_szerver&select=has_changes";
    http.begin(endpoint);
    http.addHeader("apikey", gSupabaseKey);
    http.addHeader("Authorization", String("Bearer ") + gSupabaseKey);

    int httpCode = http.GET();
    bool needsSync = true;

    if (httpCode > 0 && httpCode < 400) {
        String payload = http.getString();
        if (payload.indexOf("\"has_changes\":false") != -1) {
            needsSync = false;
        }
    }
    http.end();
    return needsSync;
}

// 4. Ha nincs változás, csak frissíti az utolsó online időbélyeget a felhőben (Heartbeat)
bool supabaseReportHeartbeatOnly() {
    if (gSupabaseUrl.length() == 0 || gSupabaseKey.length() == 0) return false;
    if (WiFi.status() != WL_CONNECTED) return false;

    HTTPClient http;
    String endpoint = gSupabaseUrl + "/rest/v1/server_sync_status?device_id=eq.kaptarmonitor_szerver";
    http.begin(endpoint);
    http.addHeader("apikey", gSupabaseKey);
    http.addHeader("Authorization", String("Bearer ") + gSupabaseKey);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Prefer", "return=minimal");

    String payload = "{\"last_sync_at\":\"NOW()\"}";
    int httpCode = http.PATCH(payload);
    http.end();

    return (httpCode >= 200 && httpCode < 300);
}

#endif // ROLE_SERVER