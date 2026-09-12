//server_comm.cpp

#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_MONITOR

#include "server_comm.h"
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <esp_sleep.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <sys/time.h>



extern unsigned long wakeStartTime; // A main.cpp-ből jön

bool serverFound = false;
uint8_t serverMac[6] = {0};
uint8_t serverChannel = 1;
String currentRadioMode = "espnow"; 
volatile unsigned long lastSyncTimeMillis = 0;
volatile bool timeSynchronized = false;
Preferences serverPrefs;
volatile bool gPairingSuccess = false;

#pragma pack(push, 1)
struct PairingData {
    uint32_t magic;         
    uint8_t  msgType;       
    uint8_t  serverMac[6];
    char     ssid[32];
    char     password[32];
    uint32_t unixTime;
};
#pragma pack(pop)

void onReceive(const uint8_t *mac_addr, const uint8_t *data, int data_len) {
    if (data_len == sizeof(PairingData)) {
        PairingData* packet = (PairingData*)data;
        if (packet->magic == 0x42454553 && packet->msgType == 0x01) {
            uint8_t primaryChan;
            wifi_second_chan_t secondChan;
            esp_wifi_get_channel(&primaryChan, &secondChan);
            
            serverPrefs.begin("kaptar", false);
            serverPrefs.putBytes("srvMac", packet->serverMac, 6);
            serverPrefs.putUInt("channel", primaryChan);
            serverPrefs.putString("ssid", packet->ssid);
            serverPrefs.putString("pass", packet->password);
            serverPrefs.end();
            
            memcpy(serverMac, packet->serverMac, 6);
            serverChannel = primaryChan;
            gPairingSuccess = true;

            if (packet->unixTime > 1000000000) {
                struct timeval tv;
                tv.tv_sec = packet->unixTime;
                tv.tv_usec = 0;
                settimeofday(&tv, NULL);
                lastSyncTimeMillis = millis();
                timeSynchronized = true;
            }
        }
    }
}

void initServerComm() {
    serverPrefs.begin("kaptar", true);
    currentRadioMode = serverPrefs.getString("radio", "espnow");
    
    if (serverPrefs.getBytesLength("srvMac") == 6) {
        serverPrefs.getBytes("srvMac", serverMac, 6);
        serverChannel = serverPrefs.getUInt("channel", 1);
        serverFound = true;
    } else {
        serverFound = false;
    }
    serverPrefs.end();
}

void scanAndSyncServer() {
    gPairingSuccess = false;
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    
    if (esp_now_init() != ESP_OK) {
        Serial.println("ESP-NOW hiba!");
        return;
    }
    
    esp_now_register_recv_cb(onReceive);
    const int HOPPING_DELAY_MS = 250;
    
    for (int ch = 1; ch <= 13; ch++) {
        if (gPairingSuccess) break; 
        
        esp_wifi_set_promiscuous(true);
        esp_wifi_set_channel(ch, WIFI_SECOND_CHAN_NONE);
        esp_wifi_set_promiscuous(false);
        
        unsigned long startWait = millis();
        while (millis() - startWait < HOPPING_DELAY_MS) {
            if (gPairingSuccess) break;
            delay(10);
            yield(); 
        }
    }
    
    esp_now_deinit();
    if (gPairingSuccess) {
        serverFound = true;
        Serial.println("\n[SYNC] Szerver szinkronizálva.");
    } else {
        serverFound = false;
    }
}

void sendTelemetryJson(float temp, float hum, float pres, float zcr, uint8_t state, double bands[8]) {
    if (!serverFound) return;

    JsonDocument doc;
    doc["comm_type"] = "comm_tel";
    doc["device_mac"] = WiFi.macAddress();
    doc["timestamp"] = timeSynchronized ? time(NULL) : 0;
    doc["active_time_ms"] = millis() - wakeStartTime;

    JsonObject sensors = doc["sensors"].to<JsonObject>();
    
    JsonObject sht40 = sensors["sht40"].to<JsonObject>();
    sht40["temp_c"] = temp;
    sht40["humidity_pct"] = hum;

    JsonObject bmp280 = sensors["bmp280"].to<JsonObject>();
    bmp280["pressure_hpa"] = pres;

    JsonObject audio = sensors["audio"].to<JsonObject>();
    audio["state"] = state;
    audio["zcr"] = zcr;
    JsonArray bandsArray = audio["bands"].to<JsonArray>();
    for (int i = 0; i < 8; i++) bandsArray.add(bands[i]);

    JsonObject power = sensors["power"].to<JsonObject>();
    power["battery_v"] = 4.1; // ADC implementáció helye

    String payload;
    serializeJson(doc, payload);
    Serial.println("[COMM] " + payload);

    if (currentRadioMode == "lora") {
        // LORA küldés
    } else {
        // ESP-NOW küldés
    }
}

void goToDeepSleep(uint64_t sleepTimeMinutes) {
    unsigned long activeTime = millis() - wakeStartTime;
    Serial.printf("[SLEEP] Alvás %llu percre. Ciklus: %lu ms\n", sleepTimeMinutes, activeTime);
    
    WiFi.mode(WIFI_OFF);
    esp_sleep_enable_timer_wakeup(sleepTimeMinutes * 60 * 1000000ULL);

    #if CURRENT_MONITOR_TARGET == TARGET_ESP32_S3
        esp_sleep_enable_ext0_wakeup((gpio_num_t)WAKE_PIN, 1);
    #elif CURRENT_MONITOR_TARGET == TARGET_ESP32_C3
        esp_deep_sleep_enable_gpio_wakeup(1ULL << WAKE_PIN, ESP_GPIO_WAKEUP_GPIO_HIGH);
    #endif

    esp_deep_sleep_start();
}

#endif // ROLE_MONITOR