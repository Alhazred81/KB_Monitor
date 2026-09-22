#include "connections.h"
#include "config.h"
#include <WiFi.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <RadioLib.h>
#include <SPI.h>
#include <Preferences.h>
#include "web_common.h"
#include <esp_wifi.h>

unsigned long currentServerTimestamp = 1787680000; 
extern uint8_t gApChannel;

// ─── WEBES DIAGNOSZTIKA NAPLÓ ÉS RAM GYORSTÁR ───
static String gRadioLog = "";
RadioNodeState gRadioNodes[MAX_RADIO_NODES];
int gRadioNodeCount = 0;

String getRadioLog() { return gRadioLog; }
void clearRadioLog() { gRadioLog = ""; }

// ─── ESP-NOW DEDIKÁLT PUFFER A DIAG Csempéhez ───
#define MAX_ESP_NOW_LOGS 15
static String espNowLogs[MAX_ESP_NOW_LOGS];
static int espNowLogHead = 0;
static int espNowLogCount = 0;

uint8_t loadSavedEspNowChannel() {
    Preferences prefs;
    prefs.begin("wifi_cfg", true);
    uint8_t ch = prefs.getUChar("esp_channel", 1); 
    prefs.end();
    return ch;
}

void saveEspNowChannel(uint8_t ch) {
    Preferences prefs;
    prefs.begin("wifi_cfg", false);
    prefs.putUChar("esp_channel", ch);
    prefs.end();
}

void addEspNowLog(const String& mac, const String& info) {
    unsigned long uptimeSec = millis() / 1000;
    String line = "[" + String(uptimeSec) + "s] MAC: " + mac + " -> " + info;
    espNowLogs[espNowLogHead] = line;
    espNowLogHead = (espNowLogHead + 1) % MAX_ESP_NOW_LOGS;
    if (espNowLogCount < MAX_ESP_NOW_LOGS) espNowLogCount++;
}

String getEspNowLogsJson() {
    String json = "[";
    int start = (espNowLogCount < MAX_ESP_NOW_LOGS) ? 0 : espNowLogHead;
    for (int i = 0; i < espNowLogCount; i++) {
        if (i > 0) json += ",";
        int idx = (start + i) % MAX_ESP_NOW_LOGS;
        json += "\"" + jsEscape(espNowLogs[idx]) + "\"";
    }
    json += "]";
    return json;
}

void addLogEntry(const String& proto, const String& mac, const String& info) {
    unsigned long uptimeSec = millis() / 1000;
    String line = "[" + String(uptimeSec) + "s][" + proto + "] MAC: " + mac + " | " + info + "\n";
    Serial.print(line);
    gRadioLog = line + gRadioLog;
    if (gRadioLog.length() > 2000) gRadioLog = gRadioLog.substring(0, 2000);
}

// Gyorstár frissítő függvény
void updateNodeRamCache(const String& mac, float temp, float hum, float vbat) {
    for (int i = 0; i < gRadioNodeCount; i++) {
        if (gRadioNodes[i].macAddress == mac) {
            gRadioNodes[i].tempInt = temp;
            gRadioNodes[i].humidity = hum;
            gRadioNodes[i].vbat = vbat;
            gRadioNodes[i].lastSeen = millis();
            return;
        }
    }
    if (gRadioNodeCount < MAX_RADIO_NODES) {
        gRadioNodes[gRadioNodeCount].macAddress = mac;
        gRadioNodes[gRadioNodeCount].tempInt = temp;
        gRadioNodes[gRadioNodeCount].humidity = hum;
        gRadioNodes[gRadioNodeCount].vbat = vbat;
        gRadioNodes[gRadioNodeCount].lastSeen = millis();
        gRadioNodeCount++;
    }
}

SPIClass spiLoRa(FSPI); 
SX1262 radio = new Module(LORA_NSS, LORA_DIO1, LORA_RST, LORA_BUSY);
volatile bool loraReceivedFlag = false;

#if defined(ESP32)
  IRAM_ATTR
#endif
void setLoraFlag(void) { loraReceivedFlag = true; }

// ─── KÖZÖS JSON FELDOLGOZÓ ───
void processIncomingJson(const String& payload, const String& protocol, const String& fallbackMac) {
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (error) {
        addLogEntry(protocol, fallbackMac, "JSON hiba: " + String(error.c_str()));
        return;
    }

    // Támogatja a régi (hosszú) és az új (rövid) kulcsokat is
    String commType = doc["comm_type"] | doc["t"] | "unknown";
    if (commType == "aud") commType = "comm_aud";
    if (commType == "tel") commType = "comm_tel";

    String deviceMac = doc["device_mac"] | doc["m"] | fallbackMac;

    if (commType != "comm_tel" && commType != "comm_aud") {
        addLogEntry(protocol, deviceMac, "Ismeretlen comm_type: " + commType);
        return;
    }

    String info = "";
    if (commType == "comm_tel") {
        float vbat = doc["sensors"]["power"]["battery_v"] | doc["v"] | 0.0;
        float temp = doc["sensors"]["sht40"]["temp_c"] | doc["tp"] | 0.0;
        float hum = doc["sensors"]["sht40"]["humidity_pct"] | doc["hm"] | 0.0;
        
        info = "Akku: " + String(vbat, 2) + "V, Belső Hő: " + String(temp, 1) + "°C";
        updateNodeRamCache(deviceMac, temp, hum, vbat);
    } else {
        float zcr = doc["audio"]["zcr_hz"] | doc["a"]["z"] | doc["z"] | 0.0;
        info = "Audio csomag érkezett (ZCR: " + String(zcr, 1) + " Hz)";
    }

    addLogEntry(protocol, deviceMac, info);

    String cleanMac = deviceMac;
    cleanMac.replace(":", "");
    String filename = "/" + commType + "_" + cleanMac + ".json";

    File file = LittleFS.open(filename, FILE_WRITE);
    if (!file) {
        Serial.println("[FS] Nem sikerült megnyitni a fájlt írásra!");
        return;
    }
    serializeJson(doc, file);
    file.close();
}

// ─── ESP-NOW LOGIKA ───
void sendEspNowAck(const uint8_t *mac_addr, int rssi) {
    JsonDocument ackDoc;
    ackDoc["comm_type"] = "comm_ack";
    ackDoc["sleep_sec"] = random(5, 21);
    ackDoc["timestamp"] = currentServerTimestamp; 
    ackDoc["server_rssi"] = rssi; 

    String ackPayload;
    serializeJson(ackDoc, ackPayload);

    if (!esp_now_is_peer_exist(mac_addr)) {
        esp_now_peer_info_t peerInfo = {};
        memcpy(peerInfo.peer_addr, mac_addr, 6);
        peerInfo.channel = 0;
        peerInfo.encrypt = false;
        esp_now_add_peer(&peerInfo);
    }

    if (esp_now_send(mac_addr, (uint8_t *)ackPayload.c_str(), ackPayload.length()) != ESP_OK) {
        Serial.println("[ESP-NOW] Hiba a nyugta küldésekor!");
    } else {
        Serial.printf("[ESP-NOW] Válasz elküldve (Alvás: %ds)\n", (int)ackDoc["sleep_sec"]);
    }
}

// Kompatibilis ESP-NOW fogadó callback
void onEspNowReceive(const uint8_t *mac_addr, const uint8_t *incomingData, int len) {
    if (!mac_addr) return;

    char macStr[18];
    snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X",
             mac_addr[0], mac_addr[1], mac_addr[2], mac_addr[3], mac_addr[4], mac_addr[5]);

    int rssi = -65; 
    String payload = String((char*)incomingData, len);

    addEspNowLog(String(macStr), "Méret: " + String(len) + "b");

    String logMsg = "ESP-NOW csomag érkezett (" + String(len) + " bájt) | Nyers: " + payload;
    addLogEntry("ESP-NOW", String(macStr), logMsg);

    processIncomingJson(payload, "ESP-NOW", String(macStr));
    sendEspNowAck(mac_addr, rssi);
}

void initServerEspNow() {
    Serial.printf("[WIFI/ESP-NOW] Indítás a szinkronizált %d. csatornán...\n", gApChannel);
    
    // Rákényszerítjük a hardveres rádiót az aktuális csatornára!
    esp_wifi_set_channel(gApChannel, WIFI_SECOND_CHAN_NONE);

    if (esp_now_init() != ESP_OK) {
        Serial.println("ESP-NOW inicializálás HIBA a szerveren!");
        return;
    }
    
    // Most már a helyes, szerver-oldali callback van itt!
    esp_now_register_recv_cb((esp_now_recv_cb_t)onEspNowReceive);
    
    Serial.println("[ESP-NOW] Készen áll a rögzített csatornán.");
}

// ─── LORA (SX1262) LOGIKA ───
bool sendLoraAck(const String& targetMac, int rssi) {
    JsonDocument ackDoc;
    ackDoc["comm_type"] = "comm_ack";
    ackDoc["target_mac"] = targetMac;
    ackDoc["sleep_sec"] = random(5, 21);
    ackDoc["timestamp"] = currentServerTimestamp;
    ackDoc["server_rssi"] = rssi;

    String ackPayload;
    serializeJson(ackDoc, ackPayload);

    int state = radio.transmit(ackPayload);
    radio.startReceive();

    if (state == RADIOLIB_ERR_NONE) {
        Serial.println("[LORA] Nyugta elküldve: " + targetMac);
        return true;
    }
    Serial.printf("[LORA] Hiba a nyugta küldésekor: %d\n", state);
    return false;
}

bool initServerLoRa() {
    if(!LittleFS.begin(true)){
        Serial.println("[FS] LittleFS hiba!");
    }

    spiLoRa.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_NSS);

    int state = radio.begin(868.0, 125.0, 9, 7, 0x12, 14, 8, 1.6, false);
    if (state != RADIOLIB_ERR_NONE) {
        Serial.printf("[LORA] Init hiba: %d\n", state);
        return false;
    }

    radio.setRfSwitchPins(LORA_RXEN, LORA_TXEN);
    radio.setDio1Action(setLoraFlag);

    state = radio.startReceive();
    if (state == RADIOLIB_ERR_NONE) {
        Serial.println(F("[LORA] Készen áll (868 MHz)."));
        return true;
    }
    return false;
}

void handleLoRaReceive() {
    if (loraReceivedFlag) {
        loraReceivedFlag = false;
        String payload;
        int state = radio.readData(payload);

        if (state == RADIOLIB_ERR_NONE) {
            JsonDocument tempDoc;
            if (!deserializeJson(tempDoc, payload)) {
                String deviceMac = tempDoc["device_mac"] | "UNKNOWN";
                int rssi = radio.getRSSI();
                processIncomingJson(payload, "LORA", deviceMac);
                if (deviceMac != "UNKNOWN") sendLoraAck(deviceMac, rssi);
            }
        } else if (state == RADIOLIB_ERR_CRC_MISMATCH) {
            addLogEntry("LORA", "UNKNOWN", "CRC hiba a bejövő csomagban.");
        }
        radio.startReceive();
    }
}