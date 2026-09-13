#pragma once
#include <Arduino.h>
#include <ESPAsyncWebServer.h>

void handleSensors(AsyncWebServerRequest *request);
void handleSensConfig(AsyncWebServerRequest *request);
void handleSensToggle(AsyncWebServerRequest *request);
void handleSensStatus(AsyncWebServerRequest *request);
void handleSensTest(AsyncWebServerRequest *request);
void handleApiI2cScan(AsyncWebServerRequest *request);
void handleApiSimKnock(AsyncWebServerRequest *request);
void handleApiResetKnock(AsyncWebServerRequest *request);
void handleApiStartLearn(AsyncWebServerRequest *request);

String aht20ValueText();
String bmp280ValueText();
String ltrValueText();

String sensorRowHtml(const String& sensorKey, const String& label, bool enabled, bool hasEverRead, bool isOk, const String& valueText, const String& pinInfo = "");
String sensStatusJsonEntry(const String& key, bool enabled, bool hasEverRead, bool isOk, const String& value);