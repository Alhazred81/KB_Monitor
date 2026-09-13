#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_MONITOR

#include "server_comm.h"
#include "hive_msg.h" // A közös struktúra beemelése
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <esp_sleep.h>
#include <Preferences.h>
#include <sys/time.h>

extern unsigned long wakeStartTime;

bool serverFound = false;
uint8_t serverMac[6] = {0};
uint8_t serverChannel = 1;
String currentRadioMode = "espnow"; 
volatile unsigned long lastSyncTimeMillis = 0;
volatile bool timeSynchronized = false;
Preferences serverPrefs;
volatile bool gPairingSuccess = false;
uint8_t gMonitorId = 1; // Ezt a Preferences-ből is be lehet majd tölteni

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
    gMonitorId = serverPrefs.getUInt("mon_id", 1);
    
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

// Az új, optimalizált, JSON-mentes küldő függvény
void sendTelemetry(WakeupReason reason, float temp, float hum, float pres, float zcr, uint8_t state, double bands[8]) {
    if (!serverFound) return;

    HiveDataMsg msg = {0}; // Inicializálás nullákkal
    
    msg.monitor_id = gMonitorId;
    msg.reason = reason;
    msg.temp_c = temp;
    msg.humidity_pct = hum;
    msg.pressure_hpa = pres;
    
    // Az egyéb szenzorokat itt lehet majd kitölteni (mérleg, VOC, UH)
    msg.weight_kg = 0.0; 
    msg.feed_distance_mm = 0;
    msg.voc_index = 0;
    msg.nox_index = 0;
    
    msg.audio_zcr = zcr;
    msg.audio_state = state;
    for (int i = 0; i < 8; i++) {
        msg.audio_bands[i] = (float)bands[i];
    }
    
    msg.battery_mv = 4100; // ADC implementáció helye
    msg.active_time_ms = millis() - wakeStartTime;

    Serial.printf("[COMM] Küldés előkészítve. Csomagméret: %d bájt\n", sizeof(HiveDataMsg));

    if (currentRadioMode == "lora") {
        // LORA küldés logic ide
    } else {
        // Gyors ESP-NOW inicializálás a mentett csatornán
        WiFi.mode(WIFI_STA);
        esp_wifi_set_promiscuous(true);
        esp_wifi_set_channel(serverChannel, WIFI_SECOND_CHAN_NONE);
        esp_wifi_set_promiscuous(false);
        
        if (esp_now_init() == ESP_OK) {
            esp_now_peer_info_t peerInfo = {};
            memcpy(peerInfo.peer_addr, serverMac, 6);
            peerInfo.channel = serverChannel;
            peerInfo.encrypt = false;
            
            if (esp_now_add_peer(&peerInfo) == ESP_OK) {
                esp_err_t result = esp_now_send(serverMac, (uint8_t *) &msg, sizeof(HiveDataMsg));
                if (result == ESP_OK) {
                    Serial.println("[COMM] ESP-NOW Sikeres küldés!");
                } else {
                    Serial.println("[COMM] ESP-NOW Küldési hiba.");
                }
            }
            esp_now_deinit();
        }
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