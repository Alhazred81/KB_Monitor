//web_sensors.h

#ifndef WEB_SENSORS_H
#define WEB_SENSORS_H

#include <Arduino.h>

void handleSensors();
void handleSensConfig();
void handleSensToggle();
void handleSensStatus();
void handleSensTest();
void handleApiI2cScan();
String aht20ValueText();
String bmp280ValueText();

// Segédfüggvények deklarálása, hogy lássa őket a web_ui
String sensorRowHtml(const String& sensorKey, const String& label, bool enabled, bool hasEverRead, bool isOk, const String& valueText, const String& pinInfo = "");
String sensStatusJsonEntry(const String& key, bool enabled, bool hasEverRead, bool isOk, const String& value);

#endif