//supabase_sync.cpp

#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include "supabase_sync.h"
#include "modem_mgr.h"
#include "web_common.h"
#include <Preferences.h>

String gSupabaseUrl = "nlpfnnkinesxgxfxndnx.supabase.co";
String gSupabaseKey = "EZ_IDE_A_PUBLISHABLE_KEY"; // Vagy a beállításokból betöltve
unsigned long gLastSupabaseSync = 0;

void initSupabaseSync() {
    Preferences prefs;
    prefs.begin("supabase_cfg", true);
    gSupabaseUrl = prefs.getString("url", "nlpfnnkinesxgxfxndnx.supabase.co");
    gSupabaseKey = prefs.getString("key", "EZ_IDE_A_PUBLISHABLE_KEY");
    prefs.end();
    diagAdd("[SUPABASE] Modul inicializálva. Host: " + gSupabaseUrl);
}

bool sendTelemetryToSupabase(const char* monitorMac, float temp, float humidity, float pressure, float zcr, float weight) {
    if (!gData.active) {
        diagAdd("[SUPABASE] Nincs aktív GPRS adatkapcsolat a küldéshez.");
        return false;
    }

    // JSON payload összeállítása a hive_meters táblához (ez aktiválja a rajzási index triggert is!)
    String payload = "{";
    payload += "\"monitor_mac\":\"" + String(monitorMac) + "\",";
    payload += "\"inner_temp\":" + String(temp, 2) + ",";
    payload += "\"humidity\":" + String(humidity, 1) + ",";
    payload += "\"noise\":" + String(zcr, 1) + ",";
    payload += "\"weight\":" + String(weight, 2);
    payload += "}";

    String url = "https://" + gSupabaseUrl + "/rest/v1/hive_meters";

    diagAdd("[SUPABASE] Adatok küldése a felhőbe...");
    modemDrain(20);

    // SIM7000G HTTPS POST készítés
    modemSerial.println("AT+SHDISC");
    modemReadUntilFinal(1000);

    modemSerial.println("AT+CSSLCFG=\"sslversion\",1,4");
    modemReadUntilFinal(1000);
    modemSerial.println("AT+CSSLCFG=\"authmode\",1,0");
    modemReadUntilFinal(1000);

    modemSerial.println("AT+SHCONF=\"URL\",\"" + url + "\"");
    modemReadUntilFinal(1500);
    modemSerial.println("AT+SHCONF=\"BODYLEN\",1024");
    modemReadUntilFinal(1000);
    modemSerial.println("AT+SHCONF=\"HEADERLEN\",400");
    modemReadUntilFinal(1000);
    modemSerial.println("AT+SHCONF=\"SSLPAR\",1");
    modemReadUntilFinal(1000);

    modemSerial.println("AT+SHCONN");
    String rConn = modemReadUntilFinal(5000);
    if (rConn.indexOf("OK") < 0) {
        diagAdd("[SUPABASE] SHCONN hiba a csatlakozáskor.");
        modemSerial.println("AT+SHDISC");
        return false;
    }

    // Fejlécek beállítása
    modemSerial.println("AT+SHSTATE=1");
    modemReadUntilFinal(1000);

    // Adatok betöltése
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

    // Kérés küldése (POST = 2)
    modemSerial.println("AT+SHREQ=\"" + url + "\",2");
    String actionResp = modemReadUntilFinal(10000);

    modemSerial.println("AT+SHDISC");
    modemReadUntilFinal(1500);

    bool success = (actionResp.indexOf("+SHREQ: \"POST\"") >= 0 && actionResp.indexOf(",201,") >= 0) ||
                   (actionResp.indexOf("+SHREQ: \"POST\"") >= 0 && actionResp.indexOf(",200,") >= 0);

    if (success) {
        diagAdd("[SUPABASE] Telemetria sikeresen felküldve a felhőbe!");
    } else {
        diagAdd("[SUPABASE] Hiba a felküldéskor. Válasz: " + actionResp);
    }

    return success;
}

void supabaseSyncLoop() {
    // 5 percenként automatikus szinkronizáció a háttérben, ha van GPRS adatkapcsolat
    if (!gData.active) return;
    if (millis() - gLastSupabaseSync < 300000UL) return; 
    gLastSupabaseSync = millis();

    // Teszt adatok küldése a szerver saját MAC címével vagy egy alap kaptárral
    sendTelemetryToSupabase("AA:BB:CC:DD:EE:01", 34.5, 60.0, 1013.2, 3800.0, 35.0);
}

#endif