#pragma once

#include <Arduino.h>

// ─── Nordic UART Service (NUS) Szabványos UUID-k ────────────
#define BLE_SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHARACTERISTIC_RX_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHARACTERISTIC_TX_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// ─── Függvény deklarációk ───────────────────────────────────
void initBleServer();
void bleLoop();

// Párosítási / Kapcsolódási ablak indítása rejtett mágnesre (alapértelmezés: 180 mp)
void startBlePairingMode(uint32_t durationSec = 180);
void stopBlePairingMode();

bool isBleActive();
bool isBleConnected();

// Adatküldés a telefon felé (telemetria / válasz JSON)
void sendBleResponse(const String& json);

// Mágnes figyelése (lopásbiztos, LED-mentes)
void checkMagnetTrigger();
