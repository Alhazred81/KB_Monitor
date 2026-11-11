#include "can_comm.h"
#include "web_common.h"

// ─── TJA1043T/1 Üzemmód Vezérlés ────────────────────────────

void tja1043SetNormalMode() {
    pinMode(PIN_CAN_EN, OUTPUT);
    pinMode(PIN_CAN_STB, OUTPUT);
    
    // Normal Mode: EN = HIGH, STB_N = HIGH -> A TJA1043 bekapcsolja az INH kimenetet (táp OK)
    digitalWrite(PIN_CAN_EN, HIGH);
    digitalWrite(PIN_CAN_STB, HIGH);
    delayMicroseconds(100); // Transceiver stabilizálódási idő
}

void tja1043PowerDownEsp() {
    Serial.println("[CAN] TJA1043 Go-to-Sleep parancs: ESP32 táp lekapcsolása...");
    Serial.flush();

    // TWAI leállítása, hogy ne zavarjon be a TXD láb
    twai_stop();
    twai_driver_uninstall();

    // Biztosítjuk, hogy a TXD láb recesszív (HIGH) legyen alvás előtt
    pinMode(PIN_CAN_TX, OUTPUT);
    digitalWrite(PIN_CAN_TX, HIGH);

    // Go-to-Sleep Mode: STB_N = LOW, EN = HIGH
    // A TJA1043 min. 50 µs múlva Sleep módba lép és leejti az INH lábat (megszűnik az ESP tápja)
    digitalWrite(PIN_CAN_EN, HIGH);
    digitalWrite(PIN_CAN_STB, LOW);

    // Végtelen ciklus, amíg a kondenzátorok ki nem sülnek és a hardver le nem kapcsol
    while (true) {
        delay(100);
    }
}

// ─── TWAI (CAN) Inicializálás ───────────────────────────────

void initCanBus() {
    // 1. Azonnal Normal módba kapcsoljuk a TJA1043-at, hogy az INH (táp) aktív maradjon
    tja1043SetNormalMode();

    // 2. TWAI konfiguráció (125 kbps - ideális a hosszabb vezetékes buszokhoz és WUP-hoz)
    twai_general_config_t g_config = TWAI_GENERAL_CONFIG_DEFAULT(
        (gpio_num_t)PIN_CAN_TX, 
        (gpio_num_t)PIN_CAN_RX, 
        TWAI_MODE_NORMAL
    );
    twai_timing_config_t t_config = TWAI_TIMING_CONFIG_125KBITS();
    twai_filter_config_t f_config = TWAI_FILTER_CONFIG_ACCEPT_ALL();

    if (twai_driver_install(&g_config, &t_config, &f_config) != ESP_OK) {
        diagAdd("[CAN] HIBA: TWAI driver telepítés sikertelen!");
        return;
    }

    if (twai_start() != ESP_OK) {
        diagAdd("[CAN] HIBA: TWAI indítás sikertelen!");
        return;
    }

    diagAdd("[CAN] TJA1043T/1 Normal módban, vezetékes CAN busz (125 kbps) aktív.");
}

// ─── Üzenetküldés és Ébresztés (Szerver oldal) ──────────────

bool sendCanFrame(uint32_t id, const uint8_t* data, uint8_t len) {
    twai_message_t msg = {};
    msg.identifier = id;
    msg.extd = 0;
    msg.rtr = 0;
    msg.data_length_code = (len > 8) ? 8 : len;
    if (data && len > 0) {
        memcpy(msg.data, data, msg.data_length_code);
    }
    return (twai_transmit(&msg, pdMS_TO_TICKS(50)) == ESP_OK);
}

void sendCanWakeupPulse() {
    diagAdd("[CAN] Ébresztő keretek (WUP) küldése a buszra...");
    
    // Nullákból álló keret (garantálja a TJA1043 számára a szükséges domináns biteket)
    uint8_t wakePayload[8] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    
    // Dupla löket a biztos ébresztéshez
    sendCanFrame(CAN_ID_WAKEUP, wakePayload, 8);
    delay(20);
    sendCanFrame(CAN_ID_WAKEUP, wakePayload, 8);

    // Várakozás, amíg a kliensek tápja feláll és bebootolnak
    delay(150);
    diagAdd("[CAN] Kliensek felébredtek, parancs küldhető.");
}

void requestCanNodesTelemetry() {
    sendCanWakeupPulse();
    uint8_t cmd = 0x01; // 0x01 = Mérés indítása / Adatbekérés
    sendCanFrame(CAN_ID_CMD_POLL, &cmd, 1);
}

// ─── Fő Ciklus (Bejövő keretek feldolgozása) ────────────────

void canBusLoop() {
    twai_message_t rxMsg;

    while (twai_receive(&rxMsg, 0) == ESP_OK) {
        if (rxMsg.rtr) continue;

        #if CURRENT_DEVICE_ROLE == ROLE_SERVER
            // SZERVER OLDAL: Telemetria fogadása a vezetékes node-októl
            if (rxMsg.identifier >= CAN_ID_TELEMETRY && rxMsg.identifier < (CAN_ID_TELEMETRY + 100)) {
                uint8_t nodeId = rxMsg.identifier - CAN_ID_TELEMETRY;
                
                int16_t rawTemp = (rxMsg.data[0] << 8) | rxMsg.data[1];
                uint16_t rawHum = (rxMsg.data[2] << 8) | rxMsg.data[3];
                uint16_t rawWeight = (rxMsg.data[4] << 8) | rxMsg.data[5];
                uint16_t vbatMv = (rxMsg.data[6] << 8) | rxMsg.data[7];

                float temp = rawTemp / 100.0f;
                float hum = rawHum / 100.0f;
                float weight = rawWeight / 100.0f;
                float vbat = vbatMv / 1000.0f;

                String virtualMac = "CAN_NODE_" + String(nodeId);
                diagAdd("[CAN RX] Node #" + String(nodeId) + " | Hő: " + String(temp, 1) + "°C, Súly: " + String(weight, 1) + "kg");
                
                // Integrálás a szerver RAM gyorstárába (Supabase szinkronhoz)
                extern void updateNodeRamCache(const String& mac, float temp, float hum, float vbat);
                updateNodeRamCache(virtualMac, temp, hum, vbat);
            }
        #else
            // KLIENS OLDAL (Időjárás-állomás, Mérleg, stb.):
            if (rxMsg.identifier == CAN_ID_SLEEP_CMD) {
                // Ha a szerver altató parancsot küld, azonnal lekapcsoljuk a saját tápunkat
                tja1043PowerDownEsp();
            }
        #endif
    }

    // Bus-Off hibafigyelés és automatikus helyreállítás
    uint32_t alerts;
    if (twai_read_alerts(&alerts, 0) == ESP_OK) {
        if (alerts & TWAI_ALERT_BUS_OFF) {
            diagAdd("[CAN] Bus-Off hiba észlelve, busz helyreállítása...");
            twai_initiate_recovery();
        }
    }
}