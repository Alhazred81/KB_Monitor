#pragma once
#include <ESPAsyncWebServer.h>

void handleCfg(AsyncWebServerRequest *request);
void handleWifiScan(AsyncWebServerRequest *request);
void handleStaConnect(AsyncWebServerRequest *request);
void handleStaDisconnect(AsyncWebServerRequest *request);
void handleSaveWifi(AsyncWebServerRequest *request);
void handleTestSavePin(AsyncWebServerRequest *request);
void handleConfirmSavePin(AsyncWebServerRequest *request);
void handleSavePin(AsyncWebServerRequest *request);
void handleChangePin(AsyncWebServerRequest *request);
void handleSavePanelVer(AsyncWebServerRequest *request);
void handleLedTrigger(AsyncWebServerRequest *request);
void handleLedAuto(AsyncWebServerRequest *request);