#pragma once
#include <ESPAsyncWebServer.h>

void handleGnss(AsyncWebServerRequest *request);
void handleGnssStatus(AsyncWebServerRequest *request);
void handleGnssAssist(AsyncWebServerRequest *request);
void handleGnssCtl(AsyncWebServerRequest *request);