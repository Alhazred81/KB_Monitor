#include "web_config.h"
#include "web_common.h"
#include "modem_mgr.h"
#include <Arduino.h>
#include <WiFi.h>

extern AsyncWebServer server;

extern String gApSSID;
extern String gApPass;
extern String gStaSSID; 
extern String gStaPass; 
extern int gRadioMode;  
extern DataConnState gData; 

extern String htmlHead(const String& title, const String& activeTab);
extern String htmlFoot();

void handleConfigPage(AsyncWebServerRequest *request) {
  // Oldal betöltése előtt egy gyors frissítés a modemtől, hogy a valós státuszt lássuk
  // (Feltételezve, hogy a modem_mgr-ben van erre lekérdező függvény, pl. modemCheckStatus() vagy megvárjuk a cache-t)
  // Ha a gData struktúra frissül a hatterben, akkor ez azonnal pontos:

  String html = htmlHead("Kommunikáció", "");
  
  html += "<style>";
  html += ".switch { position: relative; display: inline-block; width: 60px; height: 34px; }";
  html += ".switch input { opacity: 0; width: 0; height: 0; }";
  html += ".slider { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: #dc2626; transition: .4s; border-radius: 34px; }";
  html += ".slider:before { position: absolute; content: \"\"; height: 26px; width: 26px; left: 4px; bottom: 4px; background-color: white; transition: .4s; border-radius: 50%; }";
  html += "input:checked + .slider { background-color: #16a34a; }"; 
  html += "input:checked + .slider:before { transform: translateX(26px); }";
  html += ".conn-status { display: inline-block; padding: 4px 12px; border-radius: 12px; font-weight: bold; color: white; font-size: 0.9em; margin-left: 10px; }";
  html += ".bg-green { background-color: #16a34a; }";
  html += ".bg-red { background-color: #dc2626; }";
  html += "</style>";

  html += "<div class='card wide'>";
  html += "<h2>📡 Kommunikációs Beállítások</h2>";
  html += "<form action='/api/save_config' method='POST'>";
  
  // --- Mobil Adatkapcsolat Főkapcsoló Csúszka ---
  html += "<h3>Mobil Adatkapcsolat (GPRS / LTE)</h3>";
  html += "<div style='display:flex; align-items:center; margin-bottom:20px;'>";
  html += "<label class='switch'>";
  html += "<input type='checkbox' name='data_conn' value='1'" + String(gData.active ? " checked" : "") + ">";
  html += "<span class='slider'></span>";
  html += "</label>";
  
  String statusText = "Inaktív";
  String statusClass = "bg-red";
  if (gData.active) {
    statusText = "Aktív (" + gData.ip + ")";
    statusClass = "bg-green";
  } else {
    statusText = "Inaktív";
    statusClass = "bg-red";
  }
  html += "<span class='conn-status " + statusClass + "'>" + statusText + "</span>";
  html += "</div>";

  // 1. Rádió protokoll
  html += "<h3>Rádió protokoll (Szerver - Kaptármonitor)</h3>";
  html += "<select name='radio_mode' class='sec' style='width:100%; padding:10px; margin-bottom:20px;'>";
  html += "<option value='0'" + String(gRadioMode == 0 ? " selected" : "") + ">ESP-NOW (2.4 GHz)</option>";
  html += "<option value='1'" + String(gRadioMode == 1 ? " selected" : "") + ">LoRa (SX1262 - 868 MHz)</option>";
  html += "</select>";

  // 2. Wi-Fi Kliens (STA)
  html += "<h3>Helyi Wi-Fi (Szerver internetkapcsolata)</h3>";
  html += "<label>SSID:</label><br>";
  html += "<input type='text' name='sta_ssid' value='" + gStaSSID + "' placeholder='Otthoni Wi-Fi neve' style='width:100%; margin-bottom:10px;'><br>";
  html += "<label>Jelszó:</label><br>";
  html += "<input type='password' name='sta_pass' value='" + gStaPass + "' placeholder='Otthoni Wi-Fi jelszó' style='width:100%; margin-bottom:20px;'><br>";

  // 3. AP Mód
  html += "<h3>Szerver AP (Hotspot) beállítások</h3>";
  html += "<label>AP SSID:</label><br>";
  html += "<input type='text' name='ap_ssid' value='" + gApSSID + "' placeholder='KB-teszt...' style='width:100%; margin-bottom:10px;'><br>";
  html += "<label>AP Jelszó (min 8 kar.):</label><br>";
  html += "<input type='text' name='ap_pass' value='" + gApPass + "' style='width:100%; margin-bottom:20px;'><br>";

  html += "<button type='submit' class='pri' style='width:100%; padding:12px;'>💾 Mentés</button>";
  html += "</form>";
  html += "</div>";

  // 4. Kényszerített AP gomb
  html += "<div class='card wide' style='margin-top:20px;'>";
  html += "<h3>Kényszerített AP Mód</h3>";
  html += "<p class='hint'>Bontja a kliens Wi-Fi kapcsolatot és azonnal AP módba kapcsol.</p>";
  html += "<button onclick=\"fetch('/api/force_ap').then(()=>alert('AP mód aktiválva. Csatlakozz az eszköz hálózatához.'));\" class='sec' style='width:100%; padding:12px; background:#dc2626; color:white;'>⚠️ Váltás AP módba most</button>";
  html += "</div>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleSaveConfig(AsyncWebServerRequest *request) {
  if (request->hasParam("radio_mode", true)) {
    gRadioMode = request->getParam("radio_mode", true)->value().toInt();
  }
  
  // Adatkapcsolat azonnali kapcsolása újraindítás nélkül
  bool shouldBeActive = request->hasParam("data_conn", true);
  if (shouldBeActive && !gData.active) {
    dataConnEnable();
  } else if (!shouldBeActive && gData.active) {
    dataConnDisable();
  }

  if (request->hasParam("sta_ssid", true)) {
    gStaSSID = request->getParam("sta_ssid", true)->value();
  }
  if (request->hasParam("sta_pass", true)) {
    gStaPass = request->getParam("sta_pass", true)->value();
  }
  if (request->hasParam("ap_ssid", true)) {
    gApSSID = request->getParam("ap_ssid", true)->value();
  }
  if (request->hasParam("ap_pass", true)) {
    gApPass = request->getParam("ap_pass", true)->value();
  }

  // Sikeres mentés visszajelzés azonnali visszanavigálással újraindítás helyett
  String response = htmlHead("Mentés...", "");
  response += "<div class='card wide'><h2>✅ Sikeres mentés.</h2><p>A beállítások frissültek.</p></div>";
  response += "<script>setTimeout(()=>location.href='/cfg', 1500);</script>";
  response += htmlFoot();
  
  request->send(200, "text/html", response);
}

void handleForceAp(AsyncWebServerRequest *request) {
  WiFi.disconnect(true, true);
  delay(100);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(gApSSID.c_str(), gApPass.c_str());
  
  request->send(200, "text/plain", "AP mód bekapcsolva.");
}

void initConfigRoutes() {
  server.on("/cfg", HTTP_GET, handleConfigPage);
  server.on("/api/save_config", HTTP_POST, handleSaveConfig);
  server.on("/api/force_ap", HTTP_GET, handleForceAp);
}