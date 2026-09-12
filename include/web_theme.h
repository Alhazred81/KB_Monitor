#pragma once
#include <Arduino.h>
#include <ESPAsyncWebServer.h>

// Globálisan elérhetővé tesszük a HTML generálókat
String htmlHead(const String& title, const String& activeTab);
String htmlFoot();
void handleCss(AsyncWebServerRequest *request);