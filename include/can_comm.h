#pragma once

#include <Arduino.h>
#include <driver/twai.h>
#include "config.h"

// ─── Függvények deklarációi ─────────────────────────────────

void initCanBus();
void canBusLoop();

// TJA1043T/1 hardveres üzemmódok és tápvezérlés
void tja1043SetNormalMode();
void tja1043PowerDownEsp(); // Go-to-Sleep: lekapcsolja az INH-t (és áramtalanítja az ESP32-t)

// Üzenetküldők és vezérlő parancsok (Szerver oldal)
bool sendCanFrame(uint32_t id, const uint8_t* data, uint8_t len);
void sendCanWakeupPulse();          // WUP ébresztő keretek küldése a buszra
void requestCanNodesTelemetry();    // Szerver adatbekérő parancs küldése