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
extern int gApChannel; 

extern String htmlHead(const String& title, const String& activeTab);
extern String htmlFoot();

// --- Aszinkron Wi-Fi szkenner végpont ---
void handleWifiScan(AsyncWebServerRequest *request) {
    int n = WiFi.scanComplete();
    if (n == -2) {
        // Nincs folyamatban scan, elindítjuk aszinkron módon
        WiFi.scanNetworks(true);
        request->send(200, "application/json", "{\"status\":\"scanning\"}");
    } else if (n == -1) {
        // Még szkennel
        request->send(200, "application/json", "{\"status\":\"scanning\"}");
    } else {
        // Kész a scan, JSON generálása
        String json = "[";
        for (int i = 0; i < n; ++i) {
            if (i > 0) json += ",";
            json += "{\"ssid\":\"" + WiFi.SSID(i) + "\",\"rssi\":" + String(WiFi.RSSI(i)) + "}";
        }
        json += "]";
        WiFi.scanDelete(); // Memória felszabadítása
        request->send(200, "application/json", "{\"status\":\"done\",\"networks\":" + json + "}");
    }
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
  function checkAntenna(sel) {
    if (sel.value != origRadio) {
      if (!confirm('⚠️ FIGYELEM! Mielőtt rádió protokollt váltasz, ellenőrizd: biztosan csatlakoztatva van a megfelelő antenna a szerveren? A modul károsodhat antenna nélkül!')) {
        sel.value = origRadio;
      } else {
        origRadio = sel.value;
      }
    }
  }

  function startWifiScan() {
      var btn = document.getElementById('scanBtn');
      var sel = document.getElementById('sta_ssid_sel');
      btn.disabled = true;
      btn.innerHTML = '⏳...';
      
      function pollScan() {
          fetch('/api/scan_wifi')
          .then(r => r.json())
          .then(d => {
              if(d.status === 'done') {
                  sel.innerHTML = '';
                  var foundSaved = false;
                  var savedSsid = ")script" + gStaSSID + R"script(";
                  
                  d.networks.forEach(nw => {
                      var opt = document.createElement('option');
                      opt.value = nw.ssid;
                      opt.innerHTML = nw.ssid + ' (' + nw.rssi + ' dBm)';
                      if(nw.ssid === savedSsid) { opt.selected = true; foundSaved = true; }
                      sel.appendChild(opt);
                  });
                  
                  if(!foundSaved && savedSsid !== "") {
                      var opt = document.createElement('option');
                      opt.value = savedSsid;
                      opt.innerHTML = savedSsid + ' (Mentett, nem látható)';
                      opt.selected = true;
                      sel.appendChild(opt);
                  }
                  
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

  // --- 1. Mobil Adatkapcsolat ---
  html += "<div class='card wide'>";
  html += "<h2>📡 Mobil Adatkapcsolat (GPRS / LTE)</h2>";
  html += "<div style='display:flex; align-items:center; margin-bottom:10px;'>";
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
  html += "</div>";

  // --- 2. Rádiós Hálózat ---
  html += "<div class='card wide'><h2>📻 Helyi Rádiós Hálózat</h2>";
  html += "<p class='hint'>A kaptármonitor és az időjárás-állomás párosításához szükséges hálózati adatok és protokoll.</p>";
  
  html += "<table style='width:100%; text-align:left; margin-bottom:15px;'>";
  html += "<tr style='border-bottom:1px solid var(--bg2);'><th style='padding:10px 0;'>Szerver MAC Címe:</th><td style='font-family:monospace; font-size:1.1em; font-weight:bold; color:var(--ok); text-align:right;'>" + WiFi.macAddress() + "</td></tr>";
  html += "<tr><th style='padding:10px 0;'>Aktív Csatorna (CH):</th><td style='font-size:1.1em; font-weight:bold; color:var(--pri); text-align:right;'>" + String(WiFi.channel()) + "</td></tr>";
  html += "</table>";

  html += "<label style='font-weight:bold;'>Rádió protokoll (Szerver - Végpontok):</label><br>";
  html += "<select name='radio_mode' class='sec' onchange='checkAntenna(this)' style='width:100%; padding:10px; margin-top:5px; margin-bottom:15px;'>";
  html += "<option value='0'" + String(gRadioMode == 0 ? " selected" : "") + ">ESP-NOW (2.4 GHz)</option>";
  html += "<option value='1'" + String(gRadioMode == 1 ? " selected" : "") + ">LoRa (SX1262 - 868 MHz)</option>";
  html += "</select>";

  html += "<label style='font-weight:bold;'>ESP-NOW / AP Csatorna:</label><br>";
  html += "<p class='hint' style='margin-bottom:5px; margin-top:0;'>Csak akkor érvényesül, ha a szerver AP módban (terepen) működik.</p>";
  html += "<select name='ap_channel' class='sec' style='width:100%; padding:10px;'>";
  html += "<option value='1'" + String(gApChannel == 1 ? " selected" : "") + ">1. Csatorna (2412 MHz)</option>";
  html += "<option value='6'" + String(gApChannel == 6 ? " selected" : "") + ">6. Csatorna (2437 MHz)</option>";
  html += "<option value='11'" + String(gApChannel == 11 ? " selected" : "") + ">11. Csatorna (2462 MHz)</option>";
  html += "</select>";
  html += "</div>";

  // --- 3. Helyi Wi-Fi Kliens (STA) ÚJ SZKENNERREL ---
  html += "<div class='card wide'><h2>🌐 Helyi Wi-Fi (Szerver internetkapcsolata)</h2>";
  
  String staStatus = (WiFi.status() == WL_CONNECTED) ? "<span style='color:var(--ok)'>Csatlakozva: <strong>" + WiFi.SSID() + "</strong> (CH: " + String(WiFi.channel()) + ")</span>" : "<span style='color:var(--err)'>Nincs csatlakozva</span>";
  html += "<p style='margin-bottom:15px; font-size:0.95em;'>Aktuális állapot: " + staStatus + "</p>";
  
  html += "<label>SSID:</label><br>";
  html += "<div style='display:flex; gap:10px; margin-bottom:10px;'>";
  html += "<select name='sta_ssid' id='sta_ssid_sel' class='sec' style='flex:1; padding:10px;'>";
  if (gStaSSID.length() > 0) {
      html += "<option value='" + gStaSSID + "' selected>" + gStaSSID + " (Mentett)</option>";
  }
  html += "</select>";
  html += "<button type='button' id='scanBtn' class='sec' onclick='startWifiScan()' style='padding:10px; width:120px;'>🔄 Keresés</button>";
  html += "</div>";

  html += "<label>Jelszó:</label><br>";
  html += "<input type='password' name='sta_pass' value='" + gStaPass + "' placeholder='Otthoni Wi-Fi jelszó' style='width:100%; margin-bottom:10px;'><br>";
  html += "</div>";

  // --- 4. Szerver AP Mód ---
  html += "<div class='card wide'><h2>📶 Szerver AP (Hotspot) beállítások</h2>";
  html += "<label>AP SSID:</label><br>";
  html += "<input type='text' name='ap_ssid' value='" + gApSSID + "' placeholder='KB-teszt...' style='width:100%; margin-bottom:10px;'><br>";
  html += "<label>AP Jelszó (min 8 kar.):</label><br>";
  html += "<input type='text' name='ap_pass' value='" + gApPass + "' style='width:100%; margin-bottom:10px;'><br>";
  html += "</div>";

  html += "<button type='submit' class='pri' style='width:100%; padding:12px; margin-bottom:20px; font-size:1.1em;'>💾 Beállítások Mentése</button>";
  html += "</form>";

  // --- 5. Kényszerített AP gomb ---
  html += "<div class='card wide'>";
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
  
  if (request->hasParam("ap_channel", true)) {
    gApChannel = request->getParam("ap_channel", true)->value().toInt();
  }

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
  WiFi.softAP(gApSSID.c_str(), gApPass.c_str(), gApChannel); 
  
  request->send(200, "text/plain", "AP mód bekapcsolva.");
}

void initConfigRoutes() {
  server.on("/cfg", HTTP_GET, handleConfigPage);
  server.on("/api/save_config", HTTP_POST, handleSaveConfig);
  server.on("/api/force_ap", HTTP_GET, handleForceAp);
  // Az új végpont regisztrációja:
  server.on("/api/scan_wifi", HTTP_GET, handleWifiScan);
}