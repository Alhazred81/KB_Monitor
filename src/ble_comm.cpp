#include "ble_comm.h"
#include "config.h"
#include "web_common.h"
#include <NimBLEDevice.h>
#include <ArduinoJson.h>
#include <WiFi.h>

// ─── BLE Állapotváltozók ────────────────────────────────────
static NimBLEServer* pServer = nullptr;
static NimBLECharacteristic* pTxCharacteristic = nullptr;
static NimBLECharacteristic* pRxCharacteristic = nullptr;

static bool gBleActive = false;
static bool gDeviceConnected = false;
static unsigned long gBleTimeout = 0;
static unsigned long gLastLivePush = 0;
static String gBleDeviceName = "BeeServer";

// ─── Callbacks ──────────────────────────────────────────────
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) override {
        gDeviceConnected = true;
        diagAdd("[BLE] Telefon sikeresen csatlakozott! (Stealth mód, LED kikapcsolva)");
        Serial.println("[BLE] Mobil csatlakozott.");
    }

    void onDisconnect(NimBLEServer* pServer) override {
        gDeviceConnected = false;
        diagAdd("[BLE] Telefon lecsatlakozott.");
        Serial.println("[BLE] Mobil lecsatlakozott.");
        // Lecsatlakozás után azonnal leállítjuk a BLE-t, visszaadva a rádiót az ESP-NOW-nak
        stopBlePairingMode();
    }
};

class RxCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pCharacteristic) override {
        std::string rxValue = pCharacteristic->getValue();
        if (rxValue.empty()) return;

        String rxString = String(rxValue.c_str());
        Serial.println("[BLE RX] " + rxString);

        JsonDocument doc;
        DeserializationError error = deserializeJson(doc, rxString);
        if (error) {
            sendBleResponse("{\"status\":\"error\",\"msg\":\"Invalid JSON\"}");
            return;
        }

        const char* cmd = doc["cmd"] | "";

        if (strcmp(cmd, "ping") == 0) {
            sendBleResponse("{\"status\":\"pong\",\"name\":\"" + gBleDeviceName + "\"}");
        }
        else if (strcmp(cmd, "get_status") == 0) {
            // Élő telemetria és állapot küldése a telefonnak
            JsonDocument resp;
            resp["status"] = "ok";
            resp["role"] = CURRENT_DEVICE_ROLE;
            resp["comm_mode"] = IS_WIRED_CAN ? "wired_can" : "wireless";
            resp["uptime"] = millis() / 1000;
            resp["rssi"] = WiFi.RSSI();
            resp["vbat"] = 4.15; // vagy valós akku feszültség
            
            String out;
            serializeJson(resp, out);
            sendBleResponse(out);
        }
        else if (strcmp(cmd, "disconnect") == 0) {
            stopBlePairingMode();
        }
    }
};

// ─── Inicializálás ──────────────────────────────────────────
void initBleServer() {
    pinMode(PIN_HALL, INPUT_PULLUP);

    // Eszköznév generálása a Wi-Fi MAC utolsó 4 karakteréből
    String mac = WiFi.macAddress();
    mac.replace(":", "");
    String suffix = mac.substring(mac.length() - 4);
    suffix.toUpperCase();
    gBleDeviceName = "BeeServer_" + suffix;

    NimBLEDevice::init(gBleDeviceName.c_str());
    
    // Biztonsági beállítások: Passkey párosítás (123456)
    NimBLEDevice::setSecurityAuth(true, true, true);
    NimBLEDevice::setSecurityPasskey(123456);
    NimBLEDevice::setSecurityIOCap(BLE_HS_IO_DISPLAY_ONLY);

    pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    // Nordic UART Service létrehozása
    NimBLEService* pService = pServer->createService(BLE_SERVICE_UUID);

    pTxCharacteristic = pService->createCharacteristic(
        BLE_CHARACTERISTIC_TX_UUID,
        NIMBLE_PROPERTY::NOTIFY
    );

    pRxCharacteristic = pService->createCharacteristic(
        BLE_CHARACTERISTIC_RX_UUID,
        NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
    );
    pRxCharacteristic->setCallbacks(new RxCallbacks());

    pService->start();

    // Kezdetben a hirdetés ki van kapcsolva (ESP-NOW 100% szabad)
    NimBLEDevice::getAdvertising()->stop();
    gBleActive = false;

    Serial.println("[BLE] Inicializálva: " + gBleDeviceName + " (Készenlétben, alvó rádióval)");
}

// ─── Párosítási és Csatlakozási Mód ────────────────────────
void startBlePairingMode(uint32_t durationSec) {
    if (gBleActive) return;

    gBleActive = true;
    gBleTimeout = millis() + (durationSec * 1000UL);

    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
    pAdvertising->setName(gBleDeviceName.c_str());
    pAdvertising->enableScanResponse(true);
    pAdvertising->start();

    // STEALTH MÓD: Nincs semmilyen LED felkapcsolás!
    diagAdd("[BLE] Párosítási ablak aktív (" + String(durationSec) + " mp). Teljes csend és sötétség.");
    Serial.println("[BLE] Hirdetés elindult: " + gBleDeviceName);
}

void stopBlePairingMode() {
    if (!gBleActive) return;

    NimBLEDevice::getAdvertising()->stop();
    if (pServer->getConnectedCount() > 0) {
        pServer->disconnect(0);
    }

    gBleActive = false;
    gDeviceConnected = false;

    diagAdd("[BLE] Bluetooth leállítva. 2.4 GHz rádió visszatért az ESP-NOW-hoz.");
    Serial.println("[BLE] Rádió lekapcsolva.");
}

bool isBleActive() {
    return gBleActive;
}

bool isBleConnected() {
    return gDeviceConnected;
}

void sendBleResponse(const String& json) {
    if (!gDeviceConnected || !pTxCharacteristic) return;
    pTxCharacteristic->setValue(json.c_str());
    pTxCharacteristic->notify();
}

// ─── Rejtett Mágnes (Hall / Reed) Figyelése ─────────────────
void checkMagnetTrigger() {
    static unsigned long magnetPressStart = 0;
    static bool triggered = false;

    // Hall szenzor aktív állapot: LOW (mágnes a doboznál)
    if (digitalRead(PIN_HALL) == LOW) {
        if (magnetPressStart == 0) {
            magnetPressStart = millis();
        } else if (millis() - magnetPressStart > 1500 && !triggered) {
            // Mágnes ott volt legalább 1.5 másodpercig -> Ébresztés!
            triggered = true;
            startBlePairingMode(180);
        }
    } else {
        magnetPressStart = 0;
        triggered = false;
    }
}

// ─── Fő Ciklus ──────────────────────────────────────────────
void bleLoop() {
    checkMagnetTrigger();

    if (!gBleActive) return;

    // Időtúllépés ellenőrzése (ha senki sem csatlakozott)
    if (!gDeviceConnected && millis() > gBleTimeout) {
        stopBlePairingMode();
        return;
    }

    // Ha a telefon csatlakozva van, 2 másodpercenként élő telemetriát tolunk át
    if (gDeviceConnected && millis() - gLastLivePush > 2000) {
        gLastLivePush = millis();

        JsonDocument liveDoc;
        liveDoc["type"] = "live_stream";
        liveDoc["uptime"] = millis() / 1000;
        liveDoc["connected"] = true;

        String payload;
        serializeJson(liveDoc, payload);
        sendBleResponse(payload);
    }
}
