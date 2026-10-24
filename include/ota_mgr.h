#pragma once
#include <Arduino.h>
#include <ESPAsyncWebServer.h>

// Globális OTA konfigurációs változók (web_diag és connections számára is elérhető)
extern bool gMonitorOtaEnabled;
extern String gMonitorOtaSsid;
extern String gMonitorOtaPass;
extern String gMonitorOtaUrl;

// Konfiguráció betöltése és mentése (Preferences / NVS)
void loadMonitorOtaConfig();
void saveMonitorOtaConfig(bool enabled, const String& ssid, const String& pass, const String& url);

// --- SZERVER OLDALI OTA FÜGGVÉNYEK ---
void triggerServerPullOta();
void processServerPullOtaLoop();
void handleServerOtaResult(AsyncWebServerRequest *request);
void handleServerOtaUpload(AsyncWebServerRequest *request, String filename, size_t index, uint8_t *data, size_t len, bool final);

// --- KAPTÁRMONITOR (KLIENS) OLDALI OTA FÜGGVÉNYEK ---
bool checkAndParseOtaCommand(const uint8_t* mac_addr, const uint8_t* data, int len, uint8_t currentChannel = 1);
void handleMonitorOtaInLoop();