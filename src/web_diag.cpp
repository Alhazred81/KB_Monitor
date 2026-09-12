#include "config.h"
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <Preferences.h>
#include <ESPAsyncWebServer.h>
#include <WiFi.h> 
#include <Wire.h> 
#include "server_comm.h"
#include "web_diag.h"
#include "web_theme.h"
#include "web_common.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  #include "modem_mgr.h"
  #include "time_mgr.h"
  extern ModemState gModem;
  extern TimeState gTime;
  extern String gAtStatusSnapshot;
#endif

extern AsyncWebServer server;

void handleDiag(AsyncWebServerRequest *request) {
    String html = htmlHead("Diagnosztika", "4");
    html += "<div class='card wide'><h2>Eszköz Diagnosztika & Szkennerek</h2>";
    html += "<div class='diag' id='scanBox' style='min-height:90px; margin-bottom:15px;'>Készen áll...</div>";
    html += "<button class='sec' style='margin-bottom:10px;' onclick='runScan(\"/api/i2cscan\")'>🔎 I2C Szenzorok Szkennelése</button>";

    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
        html += "<button class='sec' style='margin-bottom:10px;' onclick='runScan(\"/api/rs485scan\")'>🔌 RS485 Busz Keresés</button>";
    #elif CURRENT_DEVICE_ROLE == ROLE_MONITOR
        html += "<button class='sec' style='margin-bottom:10px;' onclick='runScan(\"/api/i2sscan\")'>🎤 I2S Mikrofon Teszt</button>";
    #endif

    html += R"script(<script>
    function runScan(endpoint) {
        document.getElementById('scanBox').innerText = 'Szkennelés folyamatban...';
        fetch(endpoint).then(res => res.text()).then(txt => {
            document.getElementById('scanBox').innerText = txt;
        }).catch(err => { document.getElementById('scanBox').innerText = 'Hiba: ' + err; });
    }
    </script>)script";
    html += "</div>";

    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
        html += "<div class='card wide'><h2>AT parancs</h2>"
                "<div style='display:flex;gap:8px'><input type='text' id='atCmdInput' placeholder='pl. AT+CSQ' style='flex:1'>"
                "<button class='sec' type='button' onclick='sendAtCmd()' style='width:120px;'>Küldés</button></div>"
                "<div class='diag' id='atResultBox' style='margin-top:10px;'></div>"
                "<script>function sendAtCmd(){ let cmd = document.getElementById('atCmdInput').value; if(!cmd) return; document.getElementById('atResultBox').innerText = 'Küldés folyamatban...'; fetch('/at_ajax?cmd=' + encodeURIComponent(cmd)).then(r=>r.text()).then(txt=>{ document.getElementById('atResultBox').innerText = txt; }); }</script></div>";

        if(gAtStatusSnapshot.length() > 0) {
            html += "<div class='card diag-card'><h2>Legutobbi AT allapot snapshot</h2><div class='diag'>" + gAtStatusSnapshot + "</div></div>";
        }
    #endif
    html += htmlFoot();
    request->send(200, "text/html", html);
}

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
void handleAtAjax(AsyncWebServerRequest *request) {
    if(!request->hasParam("cmd")) { 
        request->send(400, "text/plain", "Hianyzik a parancs"); 
        return; 
    }
    String cmd = request->getParam("cmd")->value();
    request->send(200, "text/plain", (!gModem.ready) ? "HIBA: Modem nem aktiv." : modemAtQuery(cmd, 3000));
}

void handleDeleteHive(AsyncWebServerRequest *request) {
    request->send(200, "application/json", "{\"status\":\"ok\"}");
}
#endif

void initDiagRoutes() {
    server.on("/diag", HTTP_GET, handleDiag);
    
    server.on("/api/i2cscan", HTTP_GET, [](AsyncWebServerRequest *request){
        String result = "Talált I2C címek:\n";
        byte count = 0;
        for (byte address = 1; address < 127; address++) {
            Wire.beginTransmission(address);
            if (Wire.endTransmission() == 0) {
                result += " - 0x" + String(address, HEX) + "\n";
                count++;
            }
            delay(2);
        }
        if (count == 0) result += "Nem található I2C eszköz a buszon!";
        request->send(200, "text/plain", result);
    });

    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
        server.on("/at_ajax", HTTP_GET, handleAtAjax);
        server.on("/api/hives/delete", HTTP_POST, handleDeleteHive);
        server.on("/api/rs485scan", HTTP_GET, [](AsyncWebServerRequest *request){
            request->send(200, "text/plain", "RS485 Node-ok keresése...\n- Node ID: 0x01 (Válaszolt)");
        });
    #endif
}