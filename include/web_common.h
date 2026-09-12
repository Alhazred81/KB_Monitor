#pragma once
#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include <DNSServer.h>
#include <Preferences.h>
#include "config.h"

extern AsyncWebServer server;
extern DNSServer dnsServer;
extern Preferences prefs;
extern String fullMac;

void initWeb();
void loopWeb();

// ─── KÖZÖS SEGÉDFÜGGVÉNYEK ÉS FORMÁZÓK ───
void diagAdd(const String& line);
String diagDump();
String stateRow(const String& key, const String& val, const String& cls);
String htmlEscape(const String& in);
String jsEscape(const String& in);
String ageText(unsigned long stamp);
String sigBar(int q);
String normalizeAtCommand(String cmd);

// Ha szükséged van a telefon/base64/iránytű függvényekre más fájlokban (pl. modem_mgr), 
// akkor azok deklarációit is ide teheted, teljesen platformfüggetlenek!
String phoneInputBlock(const String& btnId, const String& prefix);
String smartErrorBox(const String& err);
String compassAbbrev(float deg);
String base64Encode(const uint8_t* data, size_t len);
size_t base64Decode(const String& in, uint8_t* buf, size_t maxLen);

// ─── SZERVER EXKLUZÍV VÉGPONTOK ───
#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  bool checkPinGuard(AsyncWebServerRequest *request);
  void sendWaitPage(AsyncWebServerRequest *request, const String& title, const String& message, const String& nextUrl, int waitSeconds);
#endif