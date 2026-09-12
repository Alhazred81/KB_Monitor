#include <Arduino.h>
#include <Preferences.h>
#include <LittleFS.h>
#include <ESPAsyncWebServer.h>
#include "web_ui.h"
#include "web_common.h"
#include "web_hives.h"
#include "web_config.h"
#include "web_diag.h"
#include "web_supply.h"
#include "sensors.h"
#include "modem_mgr.h"
#include "gnss_mgr.h"
#include "weather_mgr.h"
#include "calendar.h"
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
extern void handleHives(AsyncWebServerRequest *request);
extern void handleHiveView(AsyncWebServerRequest *request);
extern void handleEvaluation(AsyncWebServerRequest *request);
extern void handleTreatment(AsyncWebServerRequest *request);
extern void handleGetTreatmentsJson(AsyncWebServerRequest *request);
extern void handleEvaluatePost(AsyncWebServerRequest *request);
extern void handleConfig(AsyncWebServerRequest *request);
extern void handleConfigPost(AsyncWebServerRequest *request);
extern void handleRegisterPart(AsyncWebServerRequest *request);
extern void handleRegisterPartPost(AsyncWebServerRequest *request);
extern void handleGetEvaluationsJson(AsyncWebServerRequest *request);
extern void handleGetColonyFunctionsJson(AsyncWebServerRequest *request);
extern void handleGetDiseasesJson(AsyncWebServerRequest *request);
extern void handleNfc(AsyncWebServerRequest *request);
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
extern void handleDataOn(AsyncWebServerRequest *request);
extern void handleDataOff(AsyncWebServerRequest *request);
extern void handleDataPing(AsyncWebServerRequest *request);
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
extern void handleMapStatusApi(AsyncWebServerRequest *request);
extern void handleSensors(AsyncWebServerRequest *request);
extern void handleSensConfig(AsyncWebServerRequest *request);
extern void handleSensToggle(AsyncWebServerRequest *request);
extern void handleSensStatus(AsyncWebServerRequest *request);
extern void handleSensTest(AsyncWebServerRequest *request);
extern void handleSaveWeatherCfg(AsyncWebServerRequest *request);
extern void handleTestWeatherAlert(AsyncWebServerRequest *request);
extern void handleApiI2cScan(AsyncWebServerRequest *request);
extern void handleApiWeatherSync(AsyncWebServerRequest *request);
extern void handleSaveWifi(AsyncWebServerRequest *request);
extern void handleWifiScan(AsyncWebServerRequest *request);
extern void handleStaConnect(AsyncWebServerRequest *request);
extern void handleStaDisconnect(AsyncWebServerRequest *request);
extern void handleDiag(AsyncWebServerRequest *request);
extern void handleExpert(AsyncWebServerRequest *request);
extern void handleAtAjax(AsyncWebServerRequest *request);
extern void handleAtStatus(AsyncWebServerRequest *request);
extern void handleExpertPost(AsyncWebServerRequest *request);
extern void handleExpertReset(AsyncWebServerRequest *request);
extern void handleExpertFullReset(AsyncWebServerRequest *request);
extern void handleGetHivesJson(AsyncWebServerRequest *request);
extern void handleDeleteHive(AsyncWebServerRequest *request);
extern void handleAddDummyHive(AsyncWebServerRequest *request);
extern void handleRegStart(AsyncWebServerRequest *request);
extern void handleRegNfc(AsyncWebServerRequest *request);
extern void handleRegQueen(AsyncWebServerRequest *request);
extern void handleRegSurvey(AsyncWebServerRequest *request);
extern void handleApiSurveyStatus(AsyncWebServerRequest *request);
extern void handleRegSummary(AsyncWebServerRequest *request);
extern void handleRegSave(AsyncWebServerRequest *request);
extern void handleRegCancel(AsyncWebServerRequest *request);
extern void handleSupply(AsyncWebServerRequest *request);

extern Aht20State gAht20;
extern Bmp280State gBmp280;
extern String aht20ValueText();
extern String bmp280ValueText();
extern String windSpeedValueText();
extern String windDirValueText();
extern String shtValueText();
extern String rainValueText();
extern String mpuValueText();
extern String ltrValueText();

void handleSetMode(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  if (request->hasParam("m")) {
    gFieldMode = (request->getParam("m")->value() == "field");
  }
  request->redirect("/");
}

#if CURRENT_DEVICE_ROLE == ROLE_MONITOR

extern float currentTemp;
extern float currentHum;
extern float currentPres;
extern float currentZCR;
extern String getHiveStateString();

void handleRoot(AsyncWebServerRequest *request) {
    String html = htmlHead("Főoldal", "1");
    html += R"rawliteral(
    <div class="card wide">
        <h2>Szenzorok és Állapot</h2>
        <div class="row"><span class="k">Hőmérséklet</span><span class="v" id="val_temp">-- °C</span></div>
        <div class="row"><span class="k">Páratartalom</span><span class="v" id="val_hum">-- %</span></div>
        <div class="row"><span class="k">Légnyomás</span><span class="v" id="val_pres">-- hPa</span></div>
        <div class="row"><span class="k">ZCR (Frekvencia)</span><span class="v" id="val_zcr">-- Hz</span></div>
        <div class="row"><span class="k">Méhcsalád állapota</span><span class="v" id="val_state">--</span></div>
    </div>
    <script>
    function updateData() {
        fetch('/api/telemetry')
        .then(response => response.json())
        .then(data => {
            document.getElementById('val_temp').innerText = data.temp.toFixed(1) + ' °C';
            document.getElementById('val_hum').innerText = data.hum.toFixed(0) + ' %';
            document.getElementById('val_pres').innerText = data.pres.toFixed(0) + ' hPa';
            document.getElementById('val_zcr').innerText = data.zcr.toFixed(0) + ' Hz';
            document.getElementById('val_state').innerText = data.state_str;
        })
        .catch(err => console.error('Hiba:', err));
    }
    setInterval(updateData, 2000);
    updateData();
    </script>
    )rawliteral";
    html += htmlFoot();
    request->send(200, "text/html", html);
}

void handleApiTelemetry(AsyncWebServerRequest *request) {
    String json = "{";
    json += "\"temp\":" + String(currentTemp) + ",";
    json += "\"hum\":" + String(currentHum) + ",";
    json += "\"pres\":" + String(currentPres) + ",";
    json += "\"zcr\":" + String(currentZCR) + ",";
    json += "\"state_str\":\"" + getHiveStateString() + "\"";
    json += "}";
    request->send(200, "application/json", json);
}

#elif CURRENT_DEVICE_ROLE == ROLE_SERVER

void handleRoot(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String html = htmlHead("Főoldal", "1");
  html += "<style>.dot { height: 8px; width: 8px; border-radius: 50%; display: inline-block; margin-right: 4px; vertical-align: middle; } .dot-g { background-color: #22c55e; box-shadow: 0 0 4px rgba(34,197,94,0.6); } .dot-y { background-color: #eab308; box-shadow: 0 0 4px rgba(234,179,8,0.6); } .dot-r { background-color: #ef4444; box-shadow: 0 0 4px rgba(239,68,68,0.6); } .compact-row { display: flex; align-items: center; justify-content: space-between; padding: 4px 0; border-bottom: 1px solid rgba(255,255,255,0.04); font-size: 12px; } .dash-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; width: 100%; align-items: start; margin-bottom: 16px; } .dash-grid > .card { margin: 0 !important; width: 100% !important; box-sizing: border-box; display: flex; flex-direction: column; }</style>";

  html += "<div style='width: 100%; display:flex; justify-content:space-between; align-items:center; margin-bottom: 16px;'><div style='font-size:20px; font-weight:bold; color:#fff;'>Műszerfal</div><div style='display:flex; align-items:center; gap:10px; background:var(--card); padding:6px 16px; border-radius:20px; border:1px solid var(--border); box-shadow: 0 4px 6px rgba(0,0,0,0.3);'><span style='font-size:13px; font-weight:bold; color:" + String(gFieldMode ? "#22c55e" : "var(--txt2)") + ";'>🌱 Terep</span><label class='sens-toggle' style='margin:0; --sens-color:#eab308;'><input type='checkbox' onchange=\"location.href='/setmode?m='+(this.checked?'setup':'field')\" " + String(!gFieldMode ? "checked" : "") + "><span class='slider'></span></label><span style='font-size:13px; font-weight:bold; color:" + String(!gFieldMode ? "#eab308" : "var(--txt2)") + ";'>⚙️ Setup</span></div></div>";

  html += "<div class='dash-grid'>";

  html += "<div class='card'><h2 style='font-size:14px; margin-bottom:8px;'>📱 NFC / RFID</h2><div style='flex:1; display:flex; align-items:stretch;'><button style='width:100%; min-height:100px; font-size:24px; font-weight:900; background:var(--accent); color:#fff; border:none; border-radius:12px; box-shadow:0 8px 16px rgba(77,77,255,0.3); text-transform:uppercase; letter-spacing:1px; cursor:pointer;' onclick=\"location.href='/nfc'\">📡 Olvasás</button></div></div>";

  String modemDot = gModem.ready ? "dot-g" : "dot-r";
  String gsmDot = gModem.registered ? "dot-g" : "dot-r";
  String netDot = gData.active ? "dot-g" : "dot-y";
  String opDot = gModem.registered ? "dot-g" : "dot-r";
  String gnssPwrDot = gGnss.enabled ? "dot-g" : "dot-r";
  String fixDot = "dot-r";
  String fixText = "Nincs";
  if (gGnss.fix) {
    if (gGnss.hdop < 2.5 && gGnss.satUsed >= 5) { fixDot = "dot-g"; fixText = "3D (" + String(gGnss.satUsed) + ")"; }
    else { fixDot = "dot-y"; fixText = "2D (" + String(gGnss.satUsed) + ")"; }
  }

  html += "<div class='card'><h2 style='font-size:14px; margin-bottom:8px;'>📶 Hálózat & GNSS</h2><div style='flex:1;'><div class='compact-row'><span><span class='dot " + modemDot + "'></span>Modem</span><b>" + String(gModem.ready ? "Kész" : "Init") + "</b></div><div class='compact-row'><span><span class='dot " + gsmDot + "'></span>GSM</span><b>" + String(gModem.registered ? "OK" : "Offline") + "</b></div><div class='compact-row'><span><span class='dot " + netDot + "'></span>Adat</span><b>" + String(gData.active ? "Aktív" : "Inaktív") + "</b></div><div class='compact-row'><span><span class='dot " + opDot + "'></span>Opr.</span><b>" + (gModem.registered ? gModem.operatorName : "-") + "</b></div><hr style='border:0; border-top:1px solid rgba(255,255,255,0.1); margin:6px 0;'><div class='compact-row'><span><span class='dot " + gnssPwrDot + "'></span>GNSS</span><b>" + String(gGnss.enabled ? "BE" : "KI") + "</b></div><div class='compact-row'><span><span class='dot " + fixDot + "'></span>Fix</span><b>" + fixText + "</b></div><div class='compact-row'><span>HDOP</span><b>" + String(gGnss.hdop, 1) + "</b></div></div>";
  if(!gFieldMode) { html += "<div style='display:flex; gap:6px; margin-top:8px;'><a href='/gsm' style='flex:1;'><button class='sec' style='padding:6px; font-size:11px; width:100%;'>GSM</button></a><a href='/gnss' style='flex:1;'><button class='sec' style='padding:6px; font-size:11px; width:100%;'>GNSS</button></a></div>"; }
  html += "</div>";

  html += "<div class='card'><h2 style='font-size:14px; margin-bottom:8px;'>🌡 Aktív Szenzorok</h2><div style='flex:1;'>";
  int activeCount = 0;
  auto addSensRow = [&](String name, bool enabled, unsigned long lastRead, String liveValue) {
    if (!enabled) return;
    activeCount++;
    String dot = "dot-g"; String val = liveValue;
    if (lastRead == 0) { dot = "dot-y"; val = "Mérés folyamatban..."; }
    else if (val.length() == 0) { dot = "dot-r"; val = "Olvasási hiba"; }
    html += "<div class='compact-row'><span><span class='dot " + dot + "'></span>" + name + "</span><b>" + val + "</b></div>";
  };
  addSensRow("Belső Hő/Pára", gSht.enabled, gSht.lastGoodRead, shtValueText());
  addSensRow("Szélsebesség", gWindSpeed.enabled, gWindSpeed.lastGoodRead, windSpeedValueText());
  addSensRow("Szélirány", gWindDir.enabled, gWindDir.lastGoodRead, windDirValueText());
  addSensRow("Csapadék", gRain.enabled, gRain.lastPoll, rainValueText());
  addSensRow("AHT20 Hő/Pára", gAht20.enabled, gAht20.lastGoodRead, aht20ValueText());
  addSensRow("BMP280 Nyomás", gBmp280.enabled, gBmp280.lastGoodRead, bmp280ValueText());
  addSensRow("UV Index", gLtr.enabled, gLtr.lastGoodRead, ltrValueText());
  addSensRow("Mérleg Dőlés", gMpu.enabled, gMpu.lastGoodRead, mpuValueText());
  if (activeCount == 0) html += "<p class='hint' style='margin:4px 0; font-size:12px;'>Nincs bekapcsolt szenzor.</p>";
  html += "</div>";
  if(!gFieldMode) html += "<a href='/sensors' style='margin-top:8px;'><button class='sec' style='padding:6px; font-size:11px; width:100%;'>Összes szenzor</button></a>";
  html += "</div>";

  html += "<div class='card'><h2 style='font-size:14px; margin-bottom:8px; display:flex; justify-content:space-between; align-items:center;'><span>🌤 Időjárás & Előrejelzés</span>";
  if (gData.active) html += "<button class='sec' style='padding:2px 8px; font-size:10px; margin:0;' onclick=\"this.innerText='Töltés...'; fetch('/api/weathersync').then(()=>setTimeout(()=>location.reload(), 3000));\">Frissítés</button>";
  html += "</h2><div style='font-size:12px; margin-bottom:6px;'><b>NTP Szinkron:</b> " + String(gTime.synced ? "Aktív" : "Várakozás") + "</div><hr style='border:0; border-top:1px solid var(--border); margin:6px 0;'><div style='flex:1;'>";
  if(gWeatherHasData) {
    const char* dayNames[] = {"Ma", "Holnap", "Holnapután"};
    const char* timeSlots[] = {"00-06", "06-12", "12-18", "18-24"};
    html += "<div style='display:flex; flex-direction:column; gap:8px;'>";
    for(int d = 0; d < 3; d++) {
      html += "<div><div style='font-weight:bold; color:var(--accent); font-size:12px; margin-bottom:4px;'>" + String(dayNames[d]) + "</div><div style='display:grid; grid-template-columns: repeat(4, 1fr); gap:6px; text-align:center; font-size:11px;'>";
      for(int b = 0; b < 4; b++) {
        float minT = gForecast[d].blocks[b].tempMin; float maxT = gForecast[d].blocks[b].tempMax; float p = gForecast[d].blocks[b].precip;
        String icon = "☀️";
        if (p > 15.0) icon = "🧊"; else if (p > 5.0) icon = "⚡"; else if (p > 0.5) icon = "🌧️"; else if ((minT + maxT) / 2.0 < 15) icon = "⛅";
        html += "<div style='background:rgba(255,255,255,0.04); padding:4px 2px; border-radius:6px; border:1px solid var(--border);'><div style='font-size:9px; color:var(--txt2);'>" + String(timeSlots[b]) + "</div><div style='font-size:14px; margin:2px 0;'>" + icon + "</div><div style='font-size:10px; font-weight:bold;'>" + String(minT, 0) + " - " + String(maxT, 0) + "°C</div></div>";
      }
      html += "</div></div>";
    }
    html += "</div><p class='hint' style='margin-top:8px; margin-bottom:0; font-size:11px;'>Frissítve: " + ageText(gLastWeatherSync) + "</p>";
  } else {
    html += "<p class='hint' style='margin:0; font-size:12px;'>Nincs elérhető időjárás adat.</p>";
  }
  html += "</div></div>";

  html += getCalendarCardHtml();
  html += "</div>";

  html += "<script>function updateClock() { var d = new Date(); var h = String(d.getHours()).padStart(2, '0'); var m = String(d.getMinutes()).padStart(2, '0'); var el = document.getElementById('liveClock'); if(el) el.innerText = h + ':' + m; } setInterval(updateClock, 1000); updateClock(); setTimeout(function(){ location.reload(); }, 10000);</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}
#endif

void webBegin() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/s.css", HTTP_GET, handleCss); 
  server.on("/cfg", HTTP_GET, handleCfg);
  server.on("/setmode", HTTP_GET, handleSetMode);
  server.on("/reinit", HTTP_POST, handleReinit);
  server.on("/esprestart", HTTP_POST, handleEspRestart);
  server.on("/hives", HTTP_GET, handleHives);
  server.on("/hive", HTTP_GET, handleHiveView);
  server.on("/treatment", HTTP_GET, handleTreatment);
  server.on("/evaluation", HTTP_GET, handleEvaluation);
  server.on("/api/evaluations", HTTP_GET, handleGetEvaluationsJson);
  server.on("/api/treatments", HTTP_GET, handleGetTreatmentsJson);
  server.on("/evaluate_post", HTTP_POST, handleEvaluatePost);
  server.on("/config", HTTP_GET, handleConfig);
  server.on("/config_post", HTTP_POST, handleConfigPost);
  server.on("/register_part", HTTP_GET, handleRegisterPart);
  server.on("/register_part_post", HTTP_POST, handleRegisterPartPost);
  server.on("/api/colony_functions", HTTP_GET, handleGetColonyFunctionsJson);
  server.on("/api/diseases", HTTP_GET, handleGetDiseasesJson);
  server.on("/supply", HTTP_GET, handleSupply);
  server.on("/nfc", HTTP_GET, handleNfc);
  server.on("/gsm", HTTP_GET, handleGsm);
  server.on("/modemstatus", HTTP_GET, handleModemStatus);
  server.on("/dosms", HTTP_POST, handleDoSms);
  server.on("/smsstatus", HTTP_GET, handleSmsStatus);
  server.on("/docall", HTTP_POST, handleDoCall);
  server.on("/hangup", HTTP_POST, handleHangup);
  server.on("/setsmsc", HTTP_POST, handleSetSmsc);
  server.on("/netauto", HTTP_POST, handleNetAuto);
  server.on("/netscan", HTTP_POST, handleNetScan);
  server.on("/netmanual", HTTP_POST, handleNetManual);
  server.on("/iot", HTTP_GET, handleIot);
  server.on("/dataon", HTTP_POST, handleDataOn);
  server.on("/dataoff", HTTP_POST, handleDataOff);
  server.on("/dataping", HTTP_POST, handleDataPing);
  server.on("/ntfy-send", HTTP_POST, handleNtfySend);
  server.on("/ntfy-poll", HTTP_POST, handleNtfyPoll);
  server.on("/save-ntfy", HTTP_POST, handleSaveNtfy);
  server.on("/save-report", HTTP_POST, handleSaveReport);
  server.on("/test-report", HTTP_POST, handleTestReport);
  server.on("/eeprombackup", HTTP_POST, handleEepromBackup);
  server.on("/eepromrestore", HTTP_POST, handleEepromRestore);
  server.on("/gnss", HTTP_GET, handleGnss);
  server.on("/gnssstatus", HTTP_GET, handleGnssStatus);
  server.on("/gnssassist", HTTP_POST, handleGnssAssist);
  server.on("/gnssctl", HTTP_POST, handleGnssCtl);
  server.on("/api/map_status", HTTP_GET, handleMapStatusApi);
  server.on("/sensors", HTTP_GET, handleSensors);
  server.on("/sensconfig", HTTP_POST, handleSensConfig);
  server.on("/senstoggle", HTTP_POST, handleSensToggle);
  server.on("/sensstatus", HTTP_GET, handleSensStatus);
  server.on("/senstest", HTTP_POST, handleSensTest);
  server.on("/saveweathercfg", HTTP_POST, handleSaveWeatherCfg);
  server.on("/testweatheralert", HTTP_POST, handleTestWeatherAlert);
  server.on("/api/i2cscan", HTTP_GET, handleApiI2cScan);
  server.on("/api/weathersync", HTTP_GET, handleApiWeatherSync);
  server.on("/savewifi", HTTP_POST, handleSaveWifi);
  server.on("/wifiscan", HTTP_POST, handleWifiScan);
  server.on("/staconnect", HTTP_POST, handleStaConnect);
  server.on("/stadisconnect", HTTP_POST, handleStaDisconnect);
  server.on("/diag", HTTP_GET, handleDiag);
  server.on("/expert", HTTP_GET, handleExpert);
  server.on("/at_ajax", HTTP_GET, handleAtAjax);
  server.on("/atstatus", HTTP_POST, handleAtStatus);
  server.on("/expertpost", HTTP_POST, handleExpertPost);
  server.on("/expertreset", HTTP_POST, handleExpertReset);
  server.on("/expertfullreset", HTTP_POST, handleExpertFullReset);
  server.on("/api/hives/list", HTTP_GET, handleGetHivesJson);
  server.on("/api/hives/delete", HTTP_POST, handleDeleteHive);
  server.on("/api/hives/add_dummy", HTTP_POST, handleAddDummyHive);
  server.on("/reg/start", HTTP_GET, handleRegStart);
  server.on("/reg/nfc", HTTP_GET, handleRegNfc);
  server.on("/reg/queen", HTTP_POST, handleRegQueen);
  server.on("/reg/survey", HTTP_POST, handleRegSurvey);
  server.on("/api/survey_status", HTTP_GET, handleApiSurveyStatus);
  server.on("/reg/summary", HTTP_GET, handleRegSummary);
  server.on("/reg/save", HTTP_POST, handleRegSave);
  server.on("/reg/cancel", HTTP_GET, handleRegCancel);

  server.serveStatic("/", LittleFS, "/");
}