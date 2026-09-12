#pragma once
#include <ESPAsyncWebServer.h>

void handleGsm(AsyncWebServerRequest *request);
void handleDoSms(AsyncWebServerRequest *request);
void handleSmsStatus(AsyncWebServerRequest *request);
void handleDoCall(AsyncWebServerRequest *request);
void handleHangup(AsyncWebServerRequest *request);
void handleSetSmsc(AsyncWebServerRequest *request);
void handleNetAuto(AsyncWebServerRequest *request);
void handleNetScan(AsyncWebServerRequest *request);
void handleNetManual(AsyncWebServerRequest *request);