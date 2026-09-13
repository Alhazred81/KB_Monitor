#pragma once
#include <Arduino.h>
#include <ESPAsyncWebServer.h>

struct HiveRegistrationContext {
  bool active = false;
  String hiveId = "";
  int totalBoxes = 0;
  String nfcUids[10];
  String queenOrigin = "";
  int queenVintage = 0;
  double finalLat = 0.0;
  double finalLon = 0.0;
};

extern HiveRegistrationContext gRegCtx;

void handleHives(AsyncWebServerRequest *request);
void handleRegStart(AsyncWebServerRequest *request);
void handleRegBarcode(AsyncWebServerRequest *request);
void handleRegQueen(AsyncWebServerRequest *request);
void handleRegSurvey(AsyncWebServerRequest *request);
void handleRegSummary(AsyncWebServerRequest *request);
void handleRegSave(AsyncWebServerRequest *request);
void handleRegCancel(AsyncWebServerRequest *request);
void handleApiSurveyStatus(AsyncWebServerRequest *request);
void handleCheckPairingAPI(AsyncWebServerRequest *request);