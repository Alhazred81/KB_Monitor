#include <Arduino.h>
#include <Preferences.h>
#include <LittleFS.h>
#include <ESPAsyncWebServer.h>
#include "web_ui.h"
#include "web_common.h"
#include "web_config.h"
#include "web_diag.h"
#include "sensors.h"
#include "modem_mgr.h"
#include "gnss_mgr.h"
#include "time_mgr.h"

extern AsyncWebServer server;
extern String gApSSID;

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  extern bool checkPinGuard(AsyncWebServerRequest *request);
#else
  bool checkPinGuard(AsyncWebServerRequest *request) { return true; }
#endif

extern String htmlHead(const String& title, const String& activeTab);
extern String htmlFoot();

bool gFieldMode = true;

extern void handleCss(AsyncWebServerRequest *request);
extern void handleCfg(AsyncWebServerRequest *request);
extern void handleReinit(AsyncWebServerRequest *request);
extern void handleEspRestart(AsyncWebServerRequest *request);
extern void handleGsm(AsyncWebServerRequest *request);
extern void handleModemStatus(AsyncWebServerRequest *request);
extern void handleDoSms(AsyncWebServerRequest *request);
extern void handleSmsStatus(AsyncWebServerRequest *request);
extern void handleDoCall(AsyncWebServerRequest *request);
extern void handleHangup(AsyncWebServerRequest *request);
extern void handleSetSmsc(AsyncWebServerRequest *request);
extern void handleNetAuto(AsyncWebServerRequest *request);
extern void handleNetScan(AsyncWebServerRequest *request);
extern void handleNetManual(AsyncWebServerRequest *request);
extern void handleIot(AsyncWebServerRequest *request);
extern void handleNtfySend(AsyncWebServerRequest *request);
extern void handleNtfyPoll(AsyncWebServerRequest *request);
extern void handleSaveNtfy(AsyncWebServerRequest *request);
extern void handleSaveReport(AsyncWebServerRequest *request);
extern void handleTestReport(AsyncWebServerRequest *request);
extern void handleEepromBackup(AsyncWebServerRequest *request);
extern void handleEepromRestore(AsyncWebServerRequest *request);
extern void handleGnss(AsyncWebServerRequest *request);
extern void handleGnssStatus(AsyncWebServerRequest *request);
extern void handleGnssAssist(AsyncWebServerRequest *request);
extern void handleGnssCtl(AsyncWebServerRequest *request);
extern void handleSensors(AsyncWebServerRequest *request);
extern void handleSensConfig(AsyncWebServerRequest *request);
extern void handleSensToggle(AsyncWebServerRequest *request);
extern void handleSensStatus(AsyncWebServerRequest *request);
extern void handleSensTest(AsyncWebServerRequest *request);
extern void handleApiI2cScan(AsyncWebServerRequest *request);
extern void handleSaveWifi(AsyncWebServerRequest *request);
extern void handleWifiScan(AsyncWebServerRequest *request);
extern void handleStaConnect(AsyncWebServerRequest *request);
extern void handleStaDisconnect(AsyncWebServerRequest *request);
extern void handleDiag(AsyncWebServerRequest *request);
extern void handleAtAjax(AsyncWebServerRequest *request);
extern void handleAtStatus(AsyncWebServerRequest *request);
extern void handleApiSimKnock(AsyncWebServerRequest *request);
extern void handleApiResetKnock(AsyncWebServerRequest *request);
extern void handleApiStartLearn(AsyncWebServerRequest *request);

// ─── LEANEZÍTETT FŐOLDAL (Csak a lényeges hardver adatok) ───
void handleRoot(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String html = htmlHead("Szerver Műszerfal", "1");
  html += "<style>"
          ".dot { height: 8px; width: 8px; border-radius: 50%; display: inline-block; margin-right: 6px; vertical-align: middle; }"
          ".dot-g { background-color: #22c55e; box-shadow: 0 0 4px rgba(34,197,94,0.6); }"
          ".dot-r { background-color: #ef4444; box-shadow: 0 0 4px rgba(239,68,68,0.6); }"
          ".compact-row { display: flex; align-items: center; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05); font-size: 13px; }"
          ".dash-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; width: 100%; }"
          "</style>";

  html += "<div style='width: 100%; margin-bottom: 16px;'><div style='font-size:18px; font-weight:bold; color:#fff;'>LilyGO Szerver Státusz</div></div>";
  html += "<div class='dash-grid'>";

  // Hálózat & Modem kártya
  String modemDot = gModem.ready ? "dot-g" : "dot-r";
  String gsmDot = gModem.registered ? "dot-g" : "dot-r";
  String netDot = gData.active ? "dot-g" : "dot-r";

  html += "<div class='card'><h2>📶 Hálózat & Modem</h2>";
  html += "<div class='compact-row'><span><span class='dot " + modemDot + "'></span>Modem Állapot</span><b>" + String(gModem.ready ? "Kész" : "Init") + "</b></div>";
  html += "<div class='compact-row'><span><span class='dot " + gsmDot + "'></span>GSM Hálózat</span><b>" + String(gModem.registered ? gModem.operatorName : "Offline") + "</b></div>";
  html += "<div class='compact-row'><span><span class='dot " + netDot + "'></span>GPRS / Supabase Adat</span><b>" + String(gData.active ? gData.ip : "Inaktív") + "</b></div>";
  html += "<div class='compact-row'><span>NTP Idő</span><b>" + (gTime.synced ? gTime.localTime : "Várakozás...") + "</b></div>";
  html += "</div>";

  // Rádiós híd (ESP-NOW) kártya
  html += "<div class='card'><h2>📡 Rádiós Híd (ESP-NOW)</h2>";
  html += "<div class='compact-row'><span>Szerver CS / Csatorna</span><b>CH " + String(WiFi.channel()) + "</b></div>";
  html += "<div class='compact-row'><span>MAC Cím</span><b style='font-family:monospace;'>" + WiFi.macAddress() + "</b></div>";
  html += "<p class='hint' style='margin-top:10px; margin-bottom:0;'>A fogadott telemetriai csomagok automatikusan továbbítódnak a Supabase felhőbe.</p>";
  html += "</div>";

  html += "</div>"; // end dash-grid

  html += "<script>setTimeout(function(){ location.reload(); }, 15000);</script>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void webBegin() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/s.css", HTTP_GET, handleCss); 
  server.on("/cfg", HTTP_GET, handleCfg);
  server.on("/gsm", HTTP_GET, handleGsm);
  server.on("/iot", HTTP_GET, handleIot);
  server.on("/gnss", HTTP_GET, handleGnss);
  server.on("/sensors", HTTP_GET, handleSensors);
  server.on("/diag", HTTP_GET, handleDiag);
  
  // Alapvető API-k és műveleti route-ok
  server.on("/reinit", HTTP_POST, handleReinit);
  server.on("/esprestart", HTTP_POST, handleEspRestart);
  server.on("/dosms", HTTP_POST, handleDoSms);
  server.on("/smsstatus", HTTP_GET, handleSmsStatus);
  server.on("/docall", HTTP_POST, handleDoCall);
  server.on("/hangup", HTTP_POST, handleHangup);
  server.on("/setsmsc", HTTP_POST, handleSetSmsc);
  server.on("/netauto", HTTP_GET, handleNetAuto);
  server.on("/netscan", HTTP_GET, handleNetScan);
  server.on("/netmanual", HTTP_GET, handleNetManual);
  server.on("/ntfysend", HTTP_POST, handleNtfySend);
  server.on("/ntfypoll", HTTP_GET, handleNtfyPoll);
  server.on("/eeprombackup", HTTP_POST, handleEepromBackup);
  server.on("/eepromrestore", HTTP_POST, handleEepromRestore);
  server.on("/gnssstatus", HTTP_GET, handleGnssStatus);
  server.on("/gnssassist", HTTP_POST, handleGnssAssist);
  server.on("/gnssctl", HTTP_POST, handleGnssCtl);
  server.on("/sensconfig", HTTP_POST, handleSensConfig);
  server.on("/senstoggle", HTTP_POST, handleSensToggle);
  server.on("/sensstatus", HTTP_GET, handleSensStatus);
  server.on("/senstest", HTTP_POST, handleSensTest);
  server.on("/api/i2cscan", HTTP_GET, handleApiI2cScan);
  server.on("/savewifi", HTTP_POST, handleSaveWifi);
  server.on("/wifiscan", HTTP_GET, handleWifiScan);
  server.on("/staconnect", HTTP_POST, handleStaConnect);
  server.on("/stadisconnect", HTTP_POST, handleStaDisconnect);
  server.on("/at_ajax", HTTP_GET, handleAtAjax);
  server.on("/atstatus", HTTP_POST, handleAtStatus);
  server.on("/api/simknock", HTTP_POST, handleApiSimKnock);
  server.on("/api/resetknock", HTTP_POST, handleApiResetKnock);
  

  server.serveStatic("/", LittleFS, "/");
}