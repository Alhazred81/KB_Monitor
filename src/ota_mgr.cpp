#include "ota_mgr.h"
#include "config.h"
#include "web_common.h"
#include <Preferences.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <HTTPUpdate.h>
#include <Update.h>
#include <ArduinoJson.h>
#include <esp_now.h>
#include <esp_wifi.h>

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  extern uint8_t gApChannel;
#endif

// --- GLOBÁLIS VÁLTOZÓK DEFINÍCIÓJA ---
bool gMonitorOtaEnabled = false;
String gMonitorOtaSsid = "";
String gMonitorOtaPass = "";
String gMonitorOtaUrl  = "http://192.168.43.1:8080/firmware.bin";

static bool sOtaCfgLoaded = false;
static volatile bool sTriggerServerPullOta = false;

// --- MONITOR OLDALI BELSŐ ÁLLAPOTVÁLTOZÓK ---
static volatile bool sMonitorOtaPending = false;
static String sMonitorSsid = "";
static String sMonitorPass = "";
static String sMonitorUrl  = "";
static uint8_t sServerMac[6] = {0};
static uint8_t sSavedEspNowChannel = 1;

void loadMonitorOtaConfig() {
    if (sOtaCfgLoaded) return;
    Preferences prefs;
    prefs.begin("ota_cfg", true);
    gMonitorOtaEnabled = prefs.getBool("en", false);
    gMonitorOtaSsid    = prefs.getString("ssid", "");
    gMonitorOtaPass    = prefs.getString("pass", "");
    gMonitorOtaUrl     = prefs.getString("url", "http://192.168.43.1:8080/firmware.bin");
    prefs.end();
    sOtaCfgLoaded = true;
}

void saveMonitorOtaConfig(bool enabled, const String& ssid, const String& pass, const String& url) {
    gMonitorOtaEnabled = enabled;
    gMonitorOtaSsid    = ssid;
    gMonitorOtaPass    = pass;
    gMonitorOtaUrl     = url;

    Preferences prefs;
    prefs.begin("ota_cfg", false);
    prefs.putBool("en", gMonitorOtaEnabled);
    prefs.putString("ssid", gMonitorOtaSsid);
    prefs.putString("pass", gMonitorOtaPass);
    prefs.putString("url", gMonitorOtaUrl);
    prefs.end();
}

// ============================================================================
// SZERVER OLDALI OTA MEGVALÓSÍTÁS
// ============================================================================
void triggerServerPullOta() {
    sTriggerServerPullOta = true;
}

void processServerPullOtaLoop() {
    if (!sTriggerServerPullOta) return;
    sTriggerServerPullOta = false;

    loadMonitorOtaConfig();
    if (gMonitorOtaSsid.length() == 0) {
        diagAdd("[OTA] Hiba: Nincs megadva Hotspot SSID!");
        return;
    }

    diagAdd("[OTA] Szerver csatlakozása a Flutter Hotspothoz: " + gMonitorOtaSsid);
    Serial.printf("[SERVER OTA] Csatlakozás a hotspothoz: %s\n", gMonitorOtaSsid.c_str());

    WiFi.mode(WIFI_AP_STA);
    WiFi.begin(gMonitorOtaSsid.c_str(), gMonitorOtaPass.c_str());

    unsigned long startAttempt = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 20000) {
        delay(250);
        Serial.print(".");
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
        IPAddress gw = WiFi.gatewayIP();
        String srvUrl = "http://" + gw.toString() + ":8080/server.bin";
        diagAdd("[OTA] Hotspot OK! Szerver FW letöltése: " + srvUrl);
        Serial.println("[SERVER OTA] Letöltés indul innen: " + srvUrl);

        WiFiClient client;
        httpUpdate.rebootOnUpdate(false);

        t_httpUpdate_return ret = httpUpdate.update(client, srvUrl);
        if (ret == HTTP_UPDATE_OK) {
            diagAdd("[OTA] Szerver FW sikeresen frissítve! Újraindítás...");
            Serial.println("[SERVER OTA] SIKER! Újraindítás...");
            delay(500);
            ESP.restart();
        } else {
            String errMsg = "[OTA] Szerver letöltési hiba (" + String(httpUpdate.getLastError()) + "): " + httpUpdate.getLastErrorString();
            diagAdd(errMsg);
            Serial.println(errMsg);
        }
    } else {
        diagAdd("[OTA] Hiba: Nem sikerült csatlakozni a telefonos hotspothoz!");
    }

    WiFi.disconnect(false);
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
      esp_wifi_set_channel(gApChannel, WIFI_SECOND_CHAN_NONE);
    #endif
}

void handleServerOtaResult(AsyncWebServerRequest *request) {
    bool ok = !Update.hasError();
    AsyncWebServerResponse *response = request->beginResponse(ok ? 200 : 500, "text/plain", ok ? "OK" : "HIBA a flashelés során!");
    response->addHeader("Connection", "close");
    request->send(response);
    if (ok) {
        diagAdd("[OTA] Szerver frissítés sikeres, újraindítás...");
        delay(600);
        ESP.restart();
    }
}

void handleServerOtaUpload(AsyncWebServerRequest *request, String filename, size_t index, uint8_t *data, size_t len, bool final) {
    if (!index) {
        Serial.printf("[OTA] Szerver frissítés indítása: %s\n", filename.c_str());
        diagAdd("[OTA] Szerver FW feltöltés indul: " + filename);
        if (!Update.begin(UPDATE_SIZE_UNKNOWN, U_FLASH)) {
            Update.printError(Serial);
        }
    }
    if (len) {
        if (Update.write(data, len) != len) {
            Update.printError(Serial);
        }
    }
    if (final) {
        if (Update.end(true)) {
            Serial.printf("[OTA] Szerver frissítés kész (%u bájt).\n", index + len);
        } else {
            Update.printError(Serial);
            diagAdd("[OTA] Hiba a szerver FW lezárásakor!");
        }
    }
}

// ============================================================================
// KAPTÁRMONITOR (KLIENS) OLDALI OTA MEGVALÓSÍTÁS
// ============================================================================
bool checkAndParseOtaCommand(const uint8_t* mac_addr, const uint8_t* data, int len, uint8_t currentChannel) {
    String payload = String((char*)data, len);
    JsonDocument doc;
    if (deserializeJson(doc, payload)) return false;

    String commType = doc["comm_type"] | doc["t"] | "";
    if (commType == "comm_ota" || commType == "ota") {
        sMonitorSsid = doc["ssid"] | "";
        sMonitorPass = doc["pass"] | "";
        sMonitorUrl  = doc["url"]  | "http://192.168.43.1:8080/firmware.bin";
        memcpy(sServerMac, mac_addr, 6);
        sSavedEspNowChannel = currentChannel;
        sMonitorOtaPending = true;
        Serial.println("[OTA] Frissítési parancs érkezett a szervertől!");
        return true;
    }
    return false;
}

void handleMonitorOtaInLoop() {
    if (!sMonitorOtaPending) return;
    sMonitorOtaPending = false;

    Serial.println("\n========================================");
    Serial.println("[OTA] KAPTÁRMONITOR FRISSÍTÉS INDÍTÁSA");
    Serial.printf("[OTA] Csatlakozás a hotspothoz: %s\n", sMonitorSsid.c_str());

    esp_now_deinit();
    WiFi.disconnect(true);
    WiFi.mode(WIFI_STA);
    WiFi.begin(sMonitorSsid.c_str(), sMonitorPass.c_str());

    unsigned long startAttempt = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 20000) {
        delay(250);
        Serial.print(".");
    }
    Serial.println();

    bool updateSuccess = false;

    if (WiFi.status() == WL_CONNECTED) {
        IPAddress gatewayIp = WiFi.gatewayIP();
        if (sMonitorUrl.indexOf("192.168.43.1") != -1 && gatewayIp != IPAddress(0, 0, 0, 0)) {
            sMonitorUrl.replace("192.168.43.1", gatewayIp.toString());
        }

        Serial.println("[OTA] Wi-Fi csatlakozva! IP: " + WiFi.localIP().toString());
        Serial.println("[OTA] Firmware letöltése innen: " + sMonitorUrl);

        WiFiClient client;
        httpUpdate.rebootOnUpdate(false);

        httpUpdate.onProgress([](int cur, int total) {
            static int lastPct = -1;
            int pct = (total > 0) ? (cur * 100 / total) : 0;
            if (pct != lastPct && pct % 10 == 0) {
                lastPct = pct;
                Serial.printf("[OTA] Letöltés és flashelés: %d%%\n", pct);
            }
        });

        t_httpUpdate_return ret = httpUpdate.update(client, sMonitorUrl);

        if (ret == HTTP_UPDATE_OK) {
            Serial.println("[OTA] SIKER! Az új firmware beírva a flash memóriába.");
            updateSuccess = true;
        } else {
            Serial.printf("[OTA] HIBA (%d): %s\n", httpUpdate.getLastError(), httpUpdate.getLastErrorString().c_str());
        }
    } else {
        Serial.println("[OTA] HIBA: Nem sikerült csatlakozni a telefonos hotspothoz!");
    }

    // Visszacsatlakozás ESP-NOW-ra és jelentés ("OK" / "NOK") küldése a szervernek
    WiFi.disconnect(true);
    WiFi.mode(WIFI_STA);
    esp_wifi_set_channel(sSavedEspNowChannel, WIFI_SECOND_CHAN_NONE);

    if (esp_now_init() == ESP_OK) {
        esp_now_peer_info_t peerInfo = {};
        memcpy(peerInfo.peer_addr, sServerMac, 6);
        peerInfo.channel = 0;
        peerInfo.encrypt = false;
        esp_now_add_peer(&peerInfo);

        String resPayload = "{\"t\":\"ota_res\",\"status\":\"" + String(updateSuccess ? "OK" : "NOK") + "\"}";
        esp_now_send(sServerMac, (uint8_t*)resPayload.c_str(), resPayload.length());
        delay(350);
    }

    if (updateSuccess) {
        Serial.println("[OTA] Újraindulás az új firmware-rel...");
        Serial.println("========================================\n");
        delay(200);
        ESP.restart();
    } else {
        Serial.println("[OTA] Frissítés sikertelen, visszatérés normál üzemmódba.");
        Serial.println("========================================\n");
    }
}