#pragma once
#include <ESPAsyncWebServer.h>

void handleEspRestart(AsyncWebServerRequest *request);
void handleExpert(AsyncWebServerRequest *request);
void handleExpertPost(AsyncWebServerRequest *request);
void handleExpertReset(AsyncWebServerRequest *request);
void handleExpertFullReset(AsyncWebServerRequest *request);
void handleDiag(AsyncWebServerRequest *request);
void handleAtAjax(AsyncWebServerRequest *request);
void handleAtStatus(AsyncWebServerRequest *request);
void handleModemStatus(AsyncWebServerRequest *request);
void handleReinit(AsyncWebServerRequest *request);
void handleGetHivesJson(AsyncWebServerRequest *request);
void handleDeleteHive(AsyncWebServerRequest *request);
void handleAddDummyHive(AsyncWebServerRequest *request);
void handleAtStatusSerial(AsyncWebServerRequest *request);
void handleApiEspNowLog(AsyncWebServerRequest *request);
void handleApiEspNowClear(AsyncWebServerRequest *request);