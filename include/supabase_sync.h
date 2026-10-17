//supabase_sync.h

#pragma once
#include <Arduino.h>

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
void initSupabaseSync();
bool sendTelemetryToSupabase(const char* monitorMac, float temp, float humidity, float pressure, float zcr, float weight);
void supabaseSyncLoop();
#endif