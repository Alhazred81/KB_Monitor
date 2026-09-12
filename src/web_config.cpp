#include "config.h"
#include <Arduino.h>
#include <Preferences.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include "web_config.h"
#include "web_common.h"
#include "web_theme.h"

// ─── KÖZÖS VÁLTOZÓK ÉS FÜGGVÉNYEK ───
extern AsyncWebServer server;
extern Preferences prefs;
extern String fullMac;

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  #include "NtfyClient.h"
  #include "wifi_sta.h"
  extern NtfyClient ntfy;
  extern String gApSSID;
  extern int gApChannel;
  extern String gNtfyServer;
  extern String gNtfyTopic;
  extern String gNtfyNickname;
  extern bool gNtfyStartupMsg;
#endif

void handleConnections(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;

    String html = htmlHead("Kapcsolatok & Hálózat", "2");

    // ─── KÖZÖS RÁDIÓ ÉS WIFI KERESÉS ───
    prefs.begin("wifi_cfg", true);
    String currentConnectedSsid = WiFi.SSID().length() ? WiFi.SSID() : prefs.getString("sta_ssid", "");
    String currentRadioMode = prefs.getString("radio_mode", "espnow");
    prefs.end();

    String espnowSelected = (currentRadioMode == "espnow") ? "selected" : "";
    String loraSelected = (currentRadioMode == "lora") ? "selected" : "";

    html += R"rawliteral(
    <div class="card wide">
        <h2>Rádió Üzemmód (Közös Protokoll)</h2>
        <select id="radioSelect">
            <option value="espnow" )rawliteral" + espnowSelected + R"rawliteral(>ESP-NOW (Alapértelmezett)</option>
            <option value="lora" )rawliteral" + loraSelected + R"rawliteral(>868 MHz (LoRa)</option>
        </select>
        <button onclick="saveRadioMode()">Mentés és Újraindítás</button>
    </div>
    
    <div class="card wide">
        <h2>Helyi Wi-Fi Csatlakozás (Teszt/Internet)</h2>
        <p class='hint'>Ha megadsz egy hálózatot, az eszköz csatlakozik hozzá (STA mód).</p>
        <div class="flex-row">
            <select id="staSsidSelect" onchange="document.getElementById('staSsid').value=this.value;" style="margin-bottom:6px;">
                <option value="">Keresés folyamatban...</option>
            </select>
            <button onclick="scanWifi()">Hálózat Keresése</button>
        </div>
        <input type="text" id="staSsid" value=")rawliteral" + currentConnectedSsid + R"rawliteral(">
        <input type="password" id="staPass" placeholder="Jelszó (üres, ha nyílt)">
        <div style="display:flex;gap:10px;">
            <button onclick="saveStaConfig()" style="flex:2">Csatlakozás</button>
            <button class='danger' onclick="disconnectSta()" style="flex:1">Lecsatlakozás</button>
        </div>
    </div>
    )rawliteral";

    // ─── SZERVER EXKLUZÍV BEÁLLÍTÁSOK (Ntfy, AP, Viharjelzés) ───
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
    
    uint8_t mac[6]; WiFi.macAddress(mac);
    char macStr[18]; snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    html += "<div class='card wide'><h2>WiFi AP & ESP-NOW (Szerver)</h2>"
            "<form action='/api/save_ap' method='POST'>"
            "<label>SSID vége (előtag: KB-teszt-)</label>"
            "<input type='text' name='ssid' value='" + (gApSSID.length() > 9 ? gApSSID.substring(9) : "") + "' maxlength='20'>"
            "<label>Jelszó (ures = változatlan)</label>"
            "<input type='password' name='pass' maxlength='31'>"
            "<label>Csatorna (AP és ESP-NOW közös)</label><select name='ch'>";
    for(int i = 1; i <= 13; i++) {
        html += "<option value='" + String(i) + "'" + (i == gApChannel ? " selected" : "") + ">Csatorna " + String(i) + "</option>";
    }
    html += "</select><div class='hint' style='margin-top:10px'>Gateway MAC-cím: " + String(macStr) + "</div>"
            "<button style='margin-top:10px;'>Mentés & Újraindulás</button></form></div>";

    html += "<div class='card wide'><h2>Ntfy Riasztási Csatorna</h2>"
            "<form action='/api/save_ntfy' method='POST'>"
            "<label>Ntfy Szerver</label><input type='text' name='ntfy_server' value='" + htmlEscape(gNtfyServer) + "'>"
            "<label>Topic neve</label><input type='text' name='ntfy_topic' value='" + htmlEscape(gNtfyTopic) + "' required>"
            "<label>Eszközazonosító (Nickname)</label><input type='text' name='ntfy_nickname' value='" + htmlEscape(gNtfyNickname) + "'>"
            "<div style='margin-top:10px'><input type='checkbox' name='ntfy_startup'" + String(gNtfyStartupMsg ? " checked" : "") + "> Rendszerindulási üzenet</div>"
            "<button style='margin-top:15px'>Ntfy Mentés</button></form></div>";

    Preferences prefsW; prefsW.begin("weather_cfg", true);
    float wRain = prefsW.getFloat("w_rain", 5.0); int wWind = prefsW.getInt("w_wind", 45); int wPrio = prefsW.getInt("w_prio", 5);
    prefsW.end();

    html += "<div class='card wide'><h2>Vihar Riasztás Beállítások</h2>"
            "<form action='/api/save_weather' method='POST'>"
            "<label>Esőintenzitás küszöb (mm/h)</label><input type='number' step='0.5' name='w_rain' value='" + String(wRain, 1) + "'>"
            "<label>Szélerősség küszöb (km/h)</label><input type='number' name='w_wind' value='" + String(wWind) + "'>"
            "<button>Mentés</button></form>"
            "<button class='sec' onclick='fetch(\"/api/test_alert\").then(()=>alert(\"Teszt elküldve!\"))' style='margin-top:15px'>⚡ Teszt Riasztás Küldése</button></div>";

    #endif

    // ─── KÖZÖS JAVASCRIPT (FETCH API ALAPON) ───
    html += R"script(<script>
    function scanWifi() {
        let select = document.getElementById('staSsidSelect');
        select.innerHTML = '<option value="">Keresés folyamatban...</option>';
        fetch('/api/scan_wifi').then(r => r.json()).then(data => {
            select.innerHTML = '<option value="">Kattints a választáshoz</option>';
            data.forEach(net => {
                let opt = document.createElement('option');
                opt.value = net.ssid; opt.textContent = net.ssid + ' (' + net.rssi + ' dBm)';
                select.appendChild(opt);
            });
        });
    }
    function saveStaConfig() {
        let s = document.getElementById('staSsid').value, p = document.getElementById('staPass').value;
        fetch('/api/save_sta', { method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'ssid='+encodeURIComponent(s)+'&pass='+encodeURIComponent(p) })
        .then(() => alert('Mentve.'));
    }
    function disconnectSta() { fetch('/api/disconnect_sta', {method:'POST'}).then(()=>alert('Lecsatlakozva.')); }
    function saveRadioMode() {
        let mode = document.getElementById('radioSelect').value;
        fetch('/api/save_radio', { method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'radio='+mode })
        .then(() => alert('Rádiómód frissítve. Újraindítás...'));
    }
    </script>)script";

    html += htmlFoot();
    request->send(200, "text/html", html);
}

// ─── API VÉGPONTOK (ASZINKRON, MIND KÉT ESZKÖZRE) ───
void handleApiSaveSta(AsyncWebServerRequest *request) {
    if (request->hasParam("ssid", true)) {
        prefs.begin("wifi_cfg", false);
        prefs.putString("sta_ssid", request->getParam("ssid", true)->value());
        if(request->hasParam("pass", true)) prefs.putString("sta_pass", request->getParam("pass", true)->value());
        prefs.end();
        
        #if CURRENT_DEVICE_ROLE == ROLE_SERVER
            wifiStaConnect(request->getParam("ssid", true)->value(), request->getParam("pass", true)->value());
        #endif
        
        request->send(200, "text/plain", "OK");
    } else {
        request->send(400, "text/plain", "Hiba");
    }
}

void handleApiDisconnectSta(AsyncWebServerRequest *request) {
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
        wifiStaDisconnect();
    #else
        WiFi.disconnect();
    #endif
    request->send(200, "text/plain", "OK");
}

void handleApiScanWifi(AsyncWebServerRequest *request) {
    int n = WiFi.scanNetworks();
    String json = "[";
    for (int i = 0; i < n; ++i) {
        if (i > 0) json += ",";
        json += "{\"ssid\":\"" + WiFi.SSID(i) + "\",\"rssi\":" + String(WiFi.RSSI(i)) + "}";
    }
    json += "]";
    WiFi.scanDelete();
    request->send(200, "application/json", json);
}

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
void handleApiSaveAp(AsyncWebServerRequest *request) {
    if (request->hasParam("ssid", true)) {
        gApSSID = "KB-teszt-" + request->getParam("ssid", true)->value();
        String pass = loadApPass();
        if(request->hasParam("pass", true) && request->getParam("pass", true)->value().length() > 0) {
            pass = request->getParam("pass", true)->value();
        }
        if(request->hasParam("ch", true)) gApChannel = request->getParam("ch", true)->value().toInt();
        
        saveApConfig(gApSSID, pass, gApChannel, loadApHide());
    }
    request->redirect("/config");
}

void handleApiSaveNtfy(AsyncWebServerRequest *request) {
    // NTFY mentési logika (a gNtfy változók frissítése és prefs mentése)
    request->redirect("/config");
}

void handleApiTestAlert(AsyncWebServerRequest *request) {
    Preferences prefsW; prefsW.begin("weather_cfg", true);
    int prio = prefsW.getInt("w_prio", 5); prefsW.end();
    bool success = ntfy.send("Ez egy teszt vihar riasztas.", "Vihar Riasztas Teszt", static_cast<NtfyPriority>(prio));
    request->send(success ? 200 : 500, "text/plain", success ? "OK" : "Error");
}
#endif