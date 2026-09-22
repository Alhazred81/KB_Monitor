#include "web_config.h"
#include "web_common.h"
#include "modem_mgr.h"
#include "wifi_sta.h"
#include <Arduino.h>
#include <WiFi.h>
#include <ArduinoJson.h>

extern AsyncWebServer server;

extern String gApSSID;
extern String gApPass;
extern String gStaSSID; 
extern String gStaPass; 
extern int gRadioMode;  
extern DataConnState gData; 
extern int gApChannel; 

extern String htmlHead(const String& title, const String& activeTab);
extern String htmlFoot();

bool gSetupMode = false; 

void handleSetMode(AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, data, len);
    if(!err) {
        String mode = doc["mode"] | "field";
        gSetupMode = (mode == "setup");
        
        Preferences prefs;
        prefs.begin("sys_cfg", false);
        prefs.putBool("setup_mode", gSetupMode);
        prefs.end();
        
        request->send(200, "application/json", "{\"status\":\"ok\"}");
    } else {
        request->send(400, "application/json", "{\"status\":\"error\"}");
    }
}

void handleGetMode(AsyncWebServerRequest *request) {
    Preferences prefs;
    prefs.begin("sys_cfg", true);
    gSetupMode = prefs.getBool("setup_mode", false);
    prefs.end();

    String json = "{\"mode\":\"" + String(gSetupMode ? "setup" : "field") + "\"}";
    request->send(200, "application/json", json);
}

void handleWifiScan(AsyncWebServerRequest *request) {
    int n = WiFi.scanComplete();
    if (n == -2) {
        WiFi.scanNetworks(true);
        request->send(200, "application/json", "{\"status\":\"scanning\"}");
    } else if (n == -1) {
        request->send(200, "application/json", "{\"status\":\"scanning\"}");
    } else {
        String json = "[";
        for (int i = 0; i < n; ++i) {
            if (i > 0) json += ",";
            json += "{\"ssid\":\"" + WiFi.SSID(i) + "\",\"rssi\":" + String(WiFi.RSSI(i)) + ",\"channel\":" + String(WiFi.channel(i)) + "}";
        }
        json += "]";
        WiFi.scanDelete(); 
        request->send(200, "application/json", "{\"status\":\"done\",\"networks\":" + json + "}");
    }
}

void handleSavedWifi(AsyncWebServerRequest *request) {
    request->send(200, "application/json", getSavedWifiJson());
}

void handleConfigPage(AsyncWebServerRequest *request) {
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

  html += R"script(<script>
  var origRadio = )script" + String(gRadioMode) + R"script(;
  var savedNets = [];
  
  window.onload = function() {
      fetch('/api/saved_wifi').then(r=>r.json()).then(data => {
          savedNets = data;
          renderDropdown([]);
      });
  };

  function checkAntenna(sel) {
    if (sel.value != origRadio) {
      if (!confirm('⚠️ FIGYELEM! Biztosan csatlakoztatva van a megfelelő antenna?')) {
        sel.value = origRadio;
      } else {
        origRadio = sel.value;
      }
    }
  }

  function renderDropdown(scanned) {
      var sel = document.getElementById('sta_ssid_sel');
      sel.innerHTML = '<option value="">-- Válassz hálózatot --</option>';
      
      if(savedNets.length > 0) {
          var grp = document.createElement('optgroup');
          grp.label = 'Mentett hálózatok';
          savedNets.forEach(s => {
              var opt = document.createElement('option');
              opt.value = s;
              opt.innerHTML = s + ' (Mentett)';
              opt.dataset.saved = 'true';
              if(s === ")script" + gStaSSID + R"script(") opt.selected = true;
              grp.appendChild(opt);
          });
          sel.appendChild(grp);
      }
      
      if(scanned.length > 0) {
          var grp2 = document.createElement('optgroup');
          grp2.label = 'Környező hálózatok';
          scanned.forEach(nw => {
              if(!savedNets.includes(nw.ssid)) {
                  var opt = document.createElement('option');
                  opt.value = nw.ssid;
                  opt.innerHTML = nw.ssid + ' (' + nw.rssi + ' dBm, CH: ' + nw.channel + ')';
                  grp2.appendChild(opt);
              }
          });
          sel.appendChild(grp2);
      }
      onSsidChange(sel);
  }

  function onSsidChange(sel) {
      if (sel.selectedIndex <= 0) return;
      var isSaved = sel.options[sel.selectedIndex].dataset.saved === 'true';
      var passInput = document.getElementsByName('sta_pass')[0];
      if (isSaved) {
          passInput.value = '';
          passInput.placeholder = '*** (Mentett jelszó, hagyd üresen)';
      } else {
          passInput.placeholder = 'Otthoni Wi-Fi jelszó';
      }
  }

  function startWifiScan() {
      var btn = document.getElementById('scanBtn');
      btn.disabled = true;
      btn.innerHTML = '⏳...';
      
      function pollScan() {
          fetch('/api/scan_wifi')
          .then(r => r.json())
          .then(d => {
              if(d.status === 'done') {
                  renderDropdown(d.networks);
                  btn.disabled = false;
                  btn.innerHTML = '🔄 Keresés';
              } else {
                  setTimeout(pollScan, 1000);
              }
          }).catch(() => {
              btn.disabled = false;
              btn.innerHTML = 'Hiba!';
          });
      }
      pollScan();
  }
  </script>)script";

  html += "<form action='/api/save_config' method='POST'>";

  // --- Mobil Adatkapcsolat ---
  html += "<div class='card wide'>";
  html += "<h2>📡 Mobil Adatkapcsolat (GPRS / LTE)</h2>";
  html += "<div style='display:flex; align-items:center; margin-bottom:10px;'>";
  html += "<label class='switch'>";
  html += "<input type='checkbox' name='data_conn' value='1'" + String(gData.active ? " checked" : "") + ">";
  html += "<span class='slider'></span>";
  html += "</label>";
  html += "<span class='conn-status " + String(gData.active ? "bg-green" : "bg-red") + "'>" + String(gData.active ? "Aktív" : "Inaktív") + "</span>";
  html += "</div></div>";

  // --- Rádiós Hálózat ---
  html += "<div class='card wide'><h2>📻 Helyi Rádiós Hálózat</h2>";
  html += "<table style='width:100%; text-align:left; margin-bottom:15px;'>";
  html += "<tr style='border-bottom:1px solid var(--bg2);'><th style='padding:10px 0;'>Szerver MAC Címe:</th><td style='font-family:monospace; font-size:1.1em; font-weight:bold; color:var(--ok); text-align:right;'>" + WiFi.macAddress() + "</td></tr>";
  html += "<tr><th style='padding:10px 0;'>Aktív Csatorna (CH):</th><td style='font-size:1.1em; font-weight:bold; color:var(--pri); text-align:right;'>" + String(WiFi.channel()) + "</td></tr>";
  html += "</table>";

  html += "<label style='font-weight:bold;'>Rádió protokoll (Szerver - Végpontok):</label><br>";
  html += "<select name='radio_mode' class='sec' onchange='checkAntenna(this)' style='width:100%; padding:10px; margin-top:5px; margin-bottom:15px;'>";
  html += "<option value='0'" + String(gRadioMode == 0 ? " selected" : "") + ">ESP-NOW (2.4 GHz)</option>";
  html += "<option value='1'" + String(gRadioMode == 1 ? " selected" : "") + ">LoRa (SX1262 - 868 MHz)</option>";
  html += "</select>";

  html += "<label style='font-weight:bold;'>ESP-NOW / AP Csatorna (Ha nincs Wi-Fi):</label><br>";
  html += "<select name='ap_channel' class='sec' style='width:100%; padding:10px;'>";
  html += "<option value='1'" + String(gApChannel == 1 ? " selected" : "") + ">1. Csatorna (2412 MHz)</option>";
  html += "<option value='6'" + String(gApChannel == 6 ? " selected" : "") + ">6. Csatorna (2437 MHz)</option>";
  html += "<option value='11'" + String(gApChannel == 11 ? " selected" : "") + ">11. Csatorna (2462 MHz)</option>";
  html += "</select></div>";

  // --- Helyi Wi-Fi Kliens (STA) ---
  html += "<div class='card wide'><h2>🌐 Helyi Wi-Fi (Kliens / AP Mód)</h2>";
  
  html += "<div style='display:flex; align-items:center; margin-bottom:15px;'>";
  html += "<label class='switch'>";
  html += "<input type='checkbox' name='enable_sta' value='1'" + String(gSta.mode != NetMode::AP ? " checked" : "") + ">";
  html += "<span class='slider'></span>";
  html += "</label>";
  html += "<span style='margin-left:10px; font-weight:bold;'>Csatlakozás Wi-Fi hálózathoz (STA mód)</span>";
  html += "</div>";

  String staStatus = (WiFi.status() == WL_CONNECTED) ? "<span style='color:var(--ok)'>Csatlakozva: <strong>" + WiFi.SSID() + "</strong> (CH: " + String(WiFi.channel()) + ")</span>" : "<span style='color:var(--err)'>Nincs csatlakozva (AP mód aktív)</span>";
  html += "<p style='margin-bottom:15px; font-size:0.95em;'>Aktuális állapot: " + staStatus + "</p>";
  
  html += "<label>SSID (Hálózat neve):</label><br>";
  html += "<div style='display:flex; gap:10px; margin-bottom:10px;'>";
  html += "<select name='sta_ssid' id='sta_ssid_sel' class='sec' style='flex:1; padding:10px;' onchange='onSsidChange(this)'></select>";
  html += "<button type='button' id='scanBtn' class='sec' onclick='startWifiScan()' style='padding:10px; width:120px;'>🔄 Keresés</button>";
  html += "</div>";

  html += "<label>Jelszó:</label><br>";
  html += "<input type='password' name='sta_pass' value='' placeholder='Otthoni Wi-Fi jelszó' style='width:100%; margin-bottom:10px;'><br>";
  html += "</div>";

  // --- Szerver AP Mód beállítások ---
  html += "<div class='card wide'><h2>📶 Szerver Hotspot (AP) beállítások</h2>";
  html += "<label>AP SSID:</label><br>";
  html += "<input type='text' name='ap_ssid' value='" + gApSSID + "' placeholder='kaptarserver_AP' style='width:100%; margin-bottom:10px;'><br>";
  html += "<label>AP Jelszó (min 8 kar.):</label><br>";
  html += "<input type='text' name='ap_pass' value='" + gApPass + "' style='width:100%; margin-bottom:10px;'><br>";
  html += "</div>";

  html += "<button type='submit' class='pri' style='width:100%; padding:12px; margin-bottom:20px; font-size:1.1em;'>💾 Beállítások Mentése</button>";
  html += "</form>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleSaveConfig(AsyncWebServerRequest *request) {
  if (request->hasParam("radio_mode", true)) gRadioMode = request->getParam("radio_mode", true)->value().toInt();
  if (request->hasParam("ap_channel", true)) gApChannel = request->getParam("ap_channel", true)->value().toInt();

  bool shouldBeActive = request->hasParam("data_conn", true);
  if (shouldBeActive && !gData.active) dataConnEnable();
  else if (!shouldBeActive && gData.active) dataConnDisable();

  if (request->hasParam("sta_ssid", true)) {
    gStaSSID = request->getParam("sta_ssid", true)->value();
    gStaSSID.trim(); 
  }
  
  if (request->hasParam("sta_pass", true)) {
    gStaPass = request->getParam("sta_pass", true)->value();
  }
  
  // Ha üresen hagytad a jelszó mezőt (mert egy mentettet választottál), előkaparjuk a memóriából
  if (gStaPass == "") {
      String savedPass = getSavedWifiPass(gStaSSID);
      if (savedPass.length() > 0) gStaPass = savedPass;
  }
  
  saveStaCreds(gStaSSID, gStaPass);

  if (request->hasParam("ap_ssid", true)) {
    gApSSID = request->getParam("ap_ssid", true)->value();
    gApSSID.trim();
  }
  if (request->hasParam("ap_pass", true)) {
    gApPass = request->getParam("ap_pass", true)->value();
  }

  Preferences prefs;
  prefs.begin("wifi_cfg", false);
  prefs.putString("ap_ssid", gApSSID);
  prefs.putString("ap_pass", gApPass);
  prefs.putInt("ap_channel", gApChannel);
  prefs.end();

  bool enableSta = request->hasParam("enable_sta", true);
  if (enableSta) {
      if (gStaSSID.length() > 0) wifiStaConnect(gStaSSID, gStaPass); 
  } else {
      wifiSuspendSta(); 
  }

  String response = htmlHead("Mentés...", "");
  response += "<div class='card wide'><h2>✅ Sikeres mentés.</h2><p>A beállítások frissültek.</p></div>";
  response += "<script>setTimeout(()=>location.href='/cfg', 1500);</script>";
  response += htmlFoot();
  
  request->send(200, "text/html", response);
}

void handleForceAp(AsyncWebServerRequest *request) {
  wifiSuspendSta();
  request->send(200, "text/plain", "AP mód bekapcsolva.");
}

void initConfigRoutes() {
  server.on("/cfg", HTTP_GET, handleConfigPage);
  server.on("/api/save_config", HTTP_POST, handleSaveConfig);
  server.on("/api/force_ap", HTTP_GET, handleForceAp);
  server.on("/api/scan_wifi", HTTP_GET, handleWifiScan);
  server.on("/api/saved_wifi", HTTP_GET, handleSavedWifi); 
  
  server.on("/api/get_mode", HTTP_GET, handleGetMode);
  server.on("/api/set_mode", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, handleSetMode);
}