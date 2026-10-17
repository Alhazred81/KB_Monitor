#pragma once

#include <Arduino.h>
#include <ESPAsyncWebServer.h>

void handleMapStatusApi(AsyncWebServerRequest *request);
void handleHiveView(AsyncWebServerRequest *request);
void handleNfc(AsyncWebServerRequest *request);

void handleTreatment(AsyncWebServerRequest *request);
void handleTreatmentPost(AsyncWebServerRequest *request);

void handleEvaluation(AsyncWebServerRequest *request);
void handleEvaluatePost(AsyncWebServerRequest *request);

void handleConfig(AsyncWebServerRequest *request);
void handleConfigPost(AsyncWebServerRequest *request);

void handleRegisterPart(AsyncWebServerRequest *request);
void handleRegisterPartPost(AsyncWebServerRequest *request);

// --- Új végpontok a fiókok és a pollen kezeléséhez ---
void handleSaveLayoutApi(AsyncWebServerRequest *request);
void handleTogglePollen(AsyncWebServerRequest *request);

// JSON API-k
void handleGetTreatmentsJson(AsyncWebServerRequest *request);
void handleGetEvaluationsJson(AsyncWebServerRequest *request);
void handleGetColonyFunctionsJson(AsyncWebServerRequest *request);
void handleGetDiseasesJson(AsyncWebServerRequest *request);