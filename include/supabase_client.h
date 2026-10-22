#pragma once
#include <Arduino.h>

String supabaseFetchHivesJson();
bool supabaseCheckSyncNeeded();
bool supabaseReportHeartbeatOnly();
bool supabaseUploadChangesAndSync(const String& payload);

extern String gSupabaseUrl;
extern String gSupabaseKey;
extern bool gHasLocalChanges;

void loadSupabaseConfig();
void saveSupabaseConfig(const String& url, const String& key);
bool supabaseTestConnection();
bool supabaseInsertTelemetry(float temp, float hum, float weight);


