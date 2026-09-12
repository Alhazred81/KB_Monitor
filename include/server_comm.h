//server_comm.h

#pragma once
#include <Arduino.h>
#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_MONITOR

extern bool serverFound;
extern volatile unsigned long lastSyncTimeMillis;
extern volatile bool timeSynchronized;
extern String currentRadioMode;

void initServerComm();
void scanAndSyncServer();
void sendTelemetryJson(float temp, float hum, float pres, float zcr, uint8_t state, double bands[8]);
void goToDeepSleep(uint64_t sleepTimeMinutes);

#endif // ROLE_MONITOR