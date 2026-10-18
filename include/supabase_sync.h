#pragma once
#include <Arduino.h>

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
extern String gSupabaseUrl;
extern String gSupabaseKey;

void initSupabaseSync();
void saveSupabaseConfig(const String& url, const String& key);
bool sendTelemetryToSupabase(const char* monitorMac, float temp, float humidity, float pressure, float zcr, float weight);
void supabaseSyncLoop();
#endif