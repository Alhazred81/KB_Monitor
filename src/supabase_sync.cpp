#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include "supabase_sync.h"
#include "modem_mgr.h"
#include "web_common.h"
#include "crypto.h"
#include <Preferences.h>

String gSupabaseUrl = "nlpfnnkinesxgxfxndnx.supabase.co";
String gSupabaseKey = "";
unsigned long gLastSupabaseSync = 0;

void initSupabaseSync() {
    Preferences prefs;
    prefs.begin("supabase_cfg", true);
    gSupabaseUrl = prefs.getString("url", "nlpfnnkinesxgxfxndnx.supabase.co");
    prefs.end();

    // Titkosított kulcs betöltése és visszafejtése
    gSupabaseKey = xteaLoadPref("supabase_cfg", "key_enc");

    diagAdd("[SUPABASE] Modul inicializálva. Host: " + gSupabaseUrl + (gSupabaseKey.length() > 0 ? " (Titkosított kulcs OK)" : " (Nincs kulcs)"));
}

void saveSupabaseConfig(const String& url, const String& key) {
    String cleanUrl = url;
    cleanUrl.trim();
    cleanUrl.replace("https://", "");
    cleanUrl.replace("http://", "");
    int slashIdx = cleanUrl.indexOf('/');
    if (slashIdx > 0) {
        cleanUrl = cleanUrl.substring(0, slashIdx);
    }

    gSupabaseUrl = cleanUrl;

    Preferences prefs;
    prefs.begin("supabase_cfg", false);
    prefs.putString("url", gSupabaseUrl);
    prefs.remove("key"); // Korábbi titkosítatlan kulcs törlése, ha volt
    prefs.end();

    if (key.length() > 0) {
        gSupabaseKey = key;
        gSupabaseKey.trim();
        // Mentés XTEA titkosítással
        xteaSavePref("supabase_cfg", "key_enc", gSupabaseKey);
    }

    diagAdd("[SUPABASE] Konfiguráció mentve (API kulcs XTEA-titkosítva). Host: " + gSupabaseUrl);
}

bool sendTelemetryToSupabase(const char* monitorMac, float temp, float humidity, float pressure, float zcr, float weight) {
    if (!gData.active) {
        diagAdd("[SUPABASE] Nincs aktív GPRS adatkapcsolat a küldéshez.");
        return false;
    }
    if (gSupabaseUrl.length() == 0 || gSupabaseKey.length() == 0) {
        diagAdd("[SUPABASE] Hiányzó URL vagy API kulcs! Állítsd be az IoT oldalon.");
        return false;
    }

    String payload = "{";
    payload += "\"monitor_mac\":\"" + String(monitorMac) + "\",";
    payload += "\"inner_temp\":" + String(temp, 2) + ",";
    payload += "\"humidity\":" + String(humidity, 1) + ",";
    payload += "\"noise\":" + String(zcr, 1) + ",";
    payload += "\"weight\":" + String(weight, 2);
    payload += "}";

    String baseUrl = "https://" + gSupabaseUrl;
    String path = "/rest/v1/hive_meters";

    diagAdd("[SUPABASE] Adatok küldése: " + baseUrl + path);
    modemDrain(20);

    modemSerial.println("AT+SHDISC");
    modemReadUntilFinal(1000);

    modemSerial.println("AT+CSSLCFG=\"sslversion\",1,4");
    modemReadUntilFinal(1000);
    modemSerial.println("AT+CSSLCFG=\"authmode\",1,0");
    modemReadUntilFinal(1000);

    modemSerial.println("AT+SHCONF=\"URL\",\"" + baseUrl + "\"");
    modemReadUntilFinal(1500);
    modemSerial.println("AT+SHCONF=\"BODYLEN\",1024");
    modemReadUntilFinal(1000);
    modemSerial.println("AT+SHCONF=\"HEADERLEN\",500");
    modemReadUntilFinal(1000);
    modemSerial.println("AT+SHCONF=\"SSLPAR\",1");
    modemReadUntilFinal(1000);

    modemSerial.println("AT+SHCONN");
    String rConn = modemReadUntilFinal(6000);
    if (rConn.indexOf("OK") < 0) {
        diagAdd("[SUPABASE] SHCONN hiba a csatlakozáskor.");
        modemSerial.println("AT+SHDISC");
        return false;
    }

    modemSerial.println("AT+SHCHEAD");
    modemReadUntilFinal(500);
    modemSerial.println("AT+SHAHEAD=\"apikey\",\"" + gSupabaseKey + "\"");
    modemReadUntilFinal(500);
    modemSerial.println("AT+SHAHEAD=\"Authorization\",\"Bearer " + gSupabaseKey + "\"");
    modemReadUntilFinal(500);
    modemSerial.println("AT+SHAHEAD=\"Content-Type\",\"application/json\"");
    modemReadUntilFinal(500);
    modemSerial.println("AT+SHAHEAD=\"Prefer\",\"return=minimal\"");
    modemReadUntilFinal(500);

    int len = payload.length();
    modemSerial.print("AT+SHDATA=");
    modemSerial.print(len);
    modemSerial.println(",10000");

    unsigned long start = millis();
    bool promptFound = false;
    while (millis() - start < 3000) {
        if (modemSerial.available()) {
            String line = modemSerial.readStringUntil('\n');
            if (line.indexOf("DOWNLOAD") >= 0) {
                promptFound = true;
                break;
            }
        }
        yield();
    }

    if (!promptFound) {
        diagAdd("[SUPABASE] SHDATA prompt időtúllépés.");
        modemSerial.println("AT+SHDISC");
        return false;
    }

    modemSerial.print(payload);
    delay(200);
    modemReadUntilFinal(2000);

    modemSerial.println("AT+SHREQ=\"" + path + "\",3");
    String actionResp = modemReadUntilFinal(10000);

    modemSerial.println("AT+SHDISC");
    modemReadUntilFinal(1500);

    bool success = (actionResp.indexOf(",201,") >= 0 || actionResp.indexOf(",200,") >= 0 || actionResp.indexOf(",204,") >= 0);

    if (success) {
        diagAdd("[SUPABASE] Telemetria sikeresen felküldve!");
    } else {
        diagAdd("[SUPABASE] Hiba a felküldéskor. Válasz: " + actionResp);
    }

    return success;
}

void supabaseSyncLoop() {
    if (!gData.active) return;
    if (millis() - gLastSupabaseSync < 300000UL) return; 
    gLastSupabaseSync = millis();

    sendTelemetryToSupabase("AA:BB:CC:DD:EE:01", 34.5, 60.0, 1013.2, 3800.0, 35.0);
}

#endif