#pragma once
#include <ESPAsyncWebServer.h>

void handleEepromBackup(AsyncWebServerRequest *request);
void handleEepromRestore(AsyncWebServerRequest *request);