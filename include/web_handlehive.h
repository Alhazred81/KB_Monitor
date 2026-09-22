#pragma once
#include <ESPAsyncWebServer.h>

void handleHiveView(AsyncWebServerRequest *request);
void handleNfc(AsyncWebServerRequest *request);
void handleMapStatusApi(AsyncWebServerRequest *request);
void handleTreatment(AsyncWebServerRequest *request);
void handleGetTreatmentsJson(AsyncWebServerRequest *request);
void handleEvaluatePost(AsyncWebServerRequest *request);
void handleGetEvaluationsJson(AsyncWebServerRequest *request);
void handleEvaluation(AsyncWebServerRequest *request);
void handleGetColonyFunctionsJson(AsyncWebServerRequest *request);
void handlePostQueenRearing(AsyncWebServerRequest *request);
void handleGetDiseasesJson(AsyncWebServerRequest *request);
void handleConfig(AsyncWebServerRequest *request);
void handleConfigPost(AsyncWebServerRequest *request);
void handleRegisterPart(AsyncWebServerRequest *request);
void handleRegisterPartPost(AsyncWebServerRequest *request);
void handleTogglePollen(AsyncWebServerRequest *request);