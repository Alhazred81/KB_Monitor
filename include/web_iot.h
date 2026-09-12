#pragma once
#include <ESPAsyncWebServer.h>

void handleIot(AsyncWebServerRequest *request);
void handleDataOn(AsyncWebServerRequest *request);
void handleDataOff(AsyncWebServerRequest *request);
void handleDataPing(AsyncWebServerRequest *request);
void handleNtfySend(AsyncWebServerRequest *request);
void handleNtfyPoll(AsyncWebServerRequest *request);
void handleSaveNtfy(AsyncWebServerRequest *request);
void handleSaveReport(AsyncWebServerRequest *request);
void handleTestReport(AsyncWebServerRequest *request);
void checkAndSendScheduledReport();
void saveReportConfig(const String& times);
String loadReportConfig();