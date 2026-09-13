#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include <Preferences.h>
#include "web_iot.h"
#include "web_common.h"
#include "web_theme.h"
#include "NtfyClient.h"
#include "modem_mgr.h"

extern AsyncWebServer server;
extern NtfyClient ntfy;
extern ModemState gModem;
extern String modemBusyReason();

String gReportTimes = "";
bool gNtfySendDone = false;
String gNtfySendResult = "";

// Riasztási beállítások
bool gWeatherAlert = true; 
int gWindAlertThreshold = 60; // km/h
int gRainAlertThreshold = 20; // mm/h
int gWeatherAlertPrio = 5;    // Ntfy prioritás vihar esetén

String loadReportConfig() {
    gReportTimes = "19:00"; 
    
    Preferences prefs;
    prefs.begin("iot_cfg", true);
    gWeatherAlert = prefs.getBool("weather_alert", true);
    gWindAlertThreshold = prefs.getInt("wind_th", 60);
    gRainAlertThreshold = prefs.getInt("rain_th", 20);
    gWeatherAlertPrio = prefs.getInt("weather_prio", 5);
    prefs.end();
    
    return gReportTimes;
}

void checkAndSendScheduledReport() {}

void handleIot(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;
    String html = htmlHead("IoT", "3");

    html += "<style>";
    html += ".switch { position: relative; display: inline-block; width: 60px; height: 34px; }";
    html += ".switch input { opacity: 0; width: 0; height: 0; }";
    html += ".slider { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: #dc2626; transition: .4s; border-radius: 34px; }";
    html += ".slider:before { position: absolute; content: \"\"; height: 26px; width: 26px; left: 4px; bottom: 4px; background-color: white; transition: .4s; border-radius: 50%; }";
    html += "input:checked + .slider { background-color: #16a34a; }"; 
    html += "input:checked + .slider:before { transform: translateX(26px); }";
    html += ".thresh-row { display: flex; align-items: center; justify-content: space-between; margin-top: 10px; }";
    html += ".thresh-input { width: 80px; padding: 5px; text-align: center; }";
    html += "</style>";

    html += R"script(<script>
    function sendAjaxNtfy(type) {
        var isStorm = (type === 'storm');
        var btnId = isStorm ? 'stormBtn' : 'ntfyBtn';
        var resId = isStorm ? 'stormResult' : 'ntfyResult';
        var prioVal = isStorm ? document.getElementById('weatherPrio').value : 3;
        
        var btn = document.getElementById(btnId);
        var res = document.getElementById(resId);
        
        btn.disabled = true;
        res.style.display = 'block';
        res.innerHTML = '<span style="color:var(--txt2)">⏳ Küldés folyamatban...</span>';
        
        // Eltároljuk a globális js objektumban, hogy a polling tudja, melyik gombot kell frissíteni
        window.currentNtfyBtn = btn;
        window.currentNtfyRes = res;
        
        var url = '/ntfysend?prio=' + prioVal + (isStorm ? '&storm=1' : '');

        fetch(url, {method: 'POST'})
        .then(function(r){ return r.json(); })
        .then(function(d){
            if(d.error) {
                res.innerHTML = '<span style="color:var(--err)">' + d.error + '</span>';
                btn.disabled = false;
            } else {
                ntfyPoll(); 
            }
        }).catch(function(e){
            res.innerHTML = '<span style="color:var(--err)">Hálózati hiba!</span>';
            btn.disabled = false;
        });
    }
    
    function ntfyPoll(){
        fetch('/ntfypoll')
        .then(function(r){ return r.json(); })
        .then(function(d){
            if(!d.done){
                setTimeout(ntfyPoll, 1000);
                return;
            }
            var res = window.currentNtfyRes;
            var btn = window.currentNtfyBtn;
            if(btn) btn.disabled = false;
            if(d.ok){
                res.innerHTML = '<span style="color:var(--ok)">✓ Üzenet sikeresen elküldve!</span>';
            } else {
                res.innerHTML = '<span style="color:var(--err)">✕ Hiba: ' + d.error + '</span>';
            }
        }).catch(function(){ setTimeout(ntfyPoll, 1500); });
    }
    </script>)script";

    // --- IDŐJÁRÁS RIASZTÁSOK CSEMPE ---
    html += "<div class='card wide'><h2>🌩️ Időjárás Riasztások</h2>";
    html += "<p class='hint'>Lokális szenzoradatok alapján indított azonnali értesítések.</p>";
    html += "<form action='/api/save_iot' method='POST'>";
    
    html += "<div style='display:flex; align-items:center; margin-bottom: 15px;'>";
    html += "<label class='switch'>";
    html += "<input type='checkbox' name='weather_alert' value='1'" + String(gWeatherAlert ? " checked" : "") + ">";
    html += "<span class='slider'></span>";
    html += "</label>";
    html += "<span style='margin-left: 10px; font-weight: bold;'>Riasztások engedélyezése</span>";
    html += "</div>";

    html += "<div class='thresh-row'>";
    html += "<label>Széllökés küszöb (km/h):</label>";
    html += "<input type='number' name='wind_th' class='thresh-input' value='" + String(gWindAlertThreshold) + "' min='0' max='150'>";
    html += "</div>";

    html += "<div class='thresh-row'>";
    html += "<label>Eső intenzitás (mm/h):</label>";
    html += "<input type='number' name='rain_th' class='thresh-input' value='" + String(gRainAlertThreshold) + "' min='0' max='100'>";
    html += "</div>";

    // Prioritás kiválasztó a viharriasztáshoz
    html += "<div class='thresh-row' style='margin-bottom: 20px; align-items: flex-start;'>";
    html += "<label style='margin-top:8px;'>Ntfy prioritás:</label>";
    html += "<select name='weather_prio' id='weatherPrio' class='sec' style='width:auto; padding:5px;'>";
    html += "<option value='3'" + String(gWeatherAlertPrio == 3 ? " selected" : "") + ">3 - Normál</option>";
    html += "<option value='4'" + String(gWeatherAlertPrio == 4 ? " selected" : "") + ">4 - Magas</option>";
    html += "<option value='5'" + String(gWeatherAlertPrio == 5 ? " selected" : "") + ">5 - Max (DND áttörés)</option>";
    html += "</select>";
    html += "</div>";

    html += "<button type='submit' class='pri' style='width:100%; padding:10px;'>💾 Beállítások Mentése</button>";
    html += "</form>";

    // Viharriasztás teszt gomb (A mentés form-on kívül, hogy ne küldjön újra posztot)
    html += "<hr style='margin: 20px 0; border: 0; border-top: 1px solid var(--bg2);'>";
    html += "<p class='hint' style='margin-bottom: 5px;'>Küld egy teszt viharriasztást a fenti legördülőben beállított prioritással.</p>";
    html += "<button id='stormBtn' type='button' class='sec' style='width:100%; padding:10px; border-color:#ca8a04; color:#ca8a04; font-weight:bold;' onclick=\"sendAjaxNtfy('storm')\">⛈️ Viharriasztás Teszt</button>";
    html += "<div id='stormResult' style='margin-top:10px; font-weight:bold; display:none;'></div>";
    
    html += "</div>";

    // --- ALAP NTFY TESZT CSEMPE ---
    html += "<div class='card wide'><h2>ntfy.sh Értesítések</h2>";
    html += "<p class='hint'>Alapértelmezett, normál (3-as prioritású) rendszerüzenet tesztje.</p>";
    html += "<button id='ntfyBtn' type='button' class='sec' onclick=\"sendAjaxNtfy('normal')\">📱 Általános Tesztüzenet</button>";
    html += "<div id='ntfyResult' style='margin-top:10px; font-weight:bold; display:none;'></div>";
    html += "</div>";
    
    html += htmlFoot();
    request->send(200, "text/html", html);
}

void handleSaveIot(AsyncWebServerRequest *request) {
    gWeatherAlert = request->hasParam("weather_alert", true);
    
    if (request->hasParam("wind_th", true)) {
        gWindAlertThreshold = request->getParam("wind_th", true)->value().toInt();
    }
    if (request->hasParam("rain_th", true)) {
        gRainAlertThreshold = request->getParam("rain_th", true)->value().toInt();
    }
    if (request->hasParam("weather_prio", true)) {
        gWeatherAlertPrio = request->getParam("weather_prio", true)->value().toInt();
    }
    
    Preferences prefs;
    prefs.begin("iot_cfg", false);
    prefs.putBool("weather_alert", gWeatherAlert);
    prefs.putInt("wind_th", gWindAlertThreshold);
    prefs.putInt("rain_th", gRainAlertThreshold);
    prefs.putInt("weather_prio", gWeatherAlertPrio);
    prefs.end();
    
    request->redirect("/iot");
}

void handleSaveNtfy(AsyncWebServerRequest *request) {
    request->redirect("/iot");
}

void handleSaveReport(AsyncWebServerRequest *request) {
    request->redirect("/iot");
}

void handleNtfySend(AsyncWebServerRequest *request) {
    Serial.println("[WEBSERVER] /ntfysend végpont meghívva!");

    if(modemBusyReason().length() > 0) {
        Serial.println("[WEBSERVER] Modem foglalt: " + modemBusyReason());
        request->send(200, "application/json", "{\"error\":\"" + modemBusyReason() + "\"}");
        return;
    }

    bool isStorm = request->hasParam("storm");
    int prioVal = 3; 
    
    if (request->hasParam("prio")) {
        prioVal = request->getParam("prio")->value().toInt();
        if (prioVal < 1) prioVal = 1;
        if (prioVal > 5) prioVal = 5;
    }

    gNtfySendDone = false;
    gNtfySendResult = "";
    
    // A címben (Title) szigorúan ASCII karakterek, hogy a URL query ne omoljon össze!
    String title = isStorm ? "VIHAR RIASZTAS TESZT" : "Teszt Riport";
    
    // A törzsben (Body) nyugodtan mehet az ékezet és az emoji is.
    String msg = isStorm ? "⚠️⛈️⚡⚡ Vihar közeledik a kaptárakhoz! ⚡⚡⛈️ (Prio: " + String(prioVal) + ")" : "Sikeres szerver tesztüzenet! (Prio: " + String(prioVal) + ")";
    
    Serial.println("[WEBSERVER] ntfy.send indítása (Prioritás: " + String(prioVal) + ")...");
    
    bool ok = ntfy.send(msg.c_str(), title.c_str(), (NtfyPriority)prioVal);
    
    Serial.println("[WEBSERVER] ntfy.send visszatérési értéke: " + String(ok ? "SIKER" : "HIBA"));
    
    gNtfySendDone = true;
    if (ok) {
        diagAdd(isStorm ? "Teszt viharriasztás elküldve." : "Teszt ntfy elküldve.");
        request->send(200, "application/json", "{\"error\":\"\",\"started\":true}");
    } else {
        gNtfySendResult = "ntfy küldési hiba";
        diagAdd("Hiba a teszt ntfy küldésekor.");
        request->send(200, "application/json", "{\"error\":\"Nem sikerült elküldeni az értesítést.\"}");
    }
}


void handleNtfyPoll(AsyncWebServerRequest *request) {
    String json = "{";
    json += "\"done\":" + String(gNtfySendDone ? "true" : "false") + ",";
    json += "\"ok\":" + String(gNtfySendDone && gNtfySendResult.length()==0 ? "true" : "false") + ",";
    json += "\"error\":\"" + gNtfySendResult + "\"";
    json += "}";
    request->send(200, "application/json", json);
}

void handleTestReport(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;
    bool sent = ntfy.send("Ez egy manuális tesztriport a rendszertől.", "Teszt Riport", (NtfyPriority)3);
    if (sent) {
        request->send(200, "text/plain", "Tesztriport sikeresen elküldve!");
    } else {
        request->send(500, "text/plain", "Az ntfy küldés nem sikerült.");
    }
}

void initIotRoutes() {
    server.on("/iot", HTTP_GET, handleIot);
    server.on("/api/save_iot", HTTP_POST, handleSaveIot);
    server.on("/ntfysend", HTTP_POST, handleNtfySend);
    server.on("/ntfypoll", HTTP_GET, handleNtfyPoll);
    server.on("/testreport", HTTP_GET, handleTestReport);
}

#endif // ROLE_SERVER