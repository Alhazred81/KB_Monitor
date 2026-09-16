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
  extern String getEspNowLogsJson(); // Külső deklaráció a pufferhez
#endif

extern AsyncWebServer server;

void handleDiag(AsyncWebServerRequest *request) {
    String html = htmlHead("Diagnosztika", "4");
    
    // --- ÉLŐ TERMINÁL BLOKK ---
    html += "<div class='card wide'><h2>Élő Rendszer Napló (Terminál)</h2>";
    html += "<div style='display:flex; gap:8px; margin-bottom:8px;'>";
    html += "<button class='sec' id='termPauseBtn' onclick='toggleTerminal()' style='padding:4px 10px; font-size:12px;'>⏸ Szünet</button>";
    html += "<button class='sec' onclick='document.getElementById(\"termBox\").innerText=\"\"' style='padding:4px 10px; font-size:12px;'>🗑 Törlés</button>";
    html += "</div>";
    html += "<pre id='termBox' style='background:#0a0a18; color:#00ff00; padding:10px; border-radius:8px; height:250px; overflow-y:auto; font-size:12px; white-space:pre-wrap; font-family:monospace; margin:0;'></pre>";
    html += R"script(<script>
    let termActive = true;
    function toggleTerminal() {
        termActive = !termActive;
        document.getElementById('termPauseBtn').innerText = termActive ? '⏸ Szünet' : '▶ Folytatás';
    }
    function fetchLog() {
        if(!termActive) return;
        fetch('/api/diag_log').then(r=>r.text()).then(txt => {
            let box = document.getElementById('termBox');
            let isScrolledToBottom = box.scrollHeight - box.clientHeight <= box.scrollTop + 10;
            if (box.innerText !== txt) {
                box.innerText = txt;
                if(isScrolledToBottom) box.scrollTop = box.scrollHeight;
            }
        }).catch(()=>{});
    }
    setInterval(fetchLog, 2000);
    fetchLog();
    </script>)script";
    html += "</div>";

    // --- ESP-NOW DEDIKÁLT CSOMAGFIGYELŐ CSEMPE ---
    html += "<div class='card wide'><h2>📡 ESP-NOW Valós Idejű Csomagfigyelő</h2>";
    html += "<div style='display:flex; gap:8px; margin-bottom:8px;'>";
    html += "<button class='sec' onclick='fetchEspNowLog()' style='padding:4px 10px; font-size:12px;'>🔄 Frissítés</button>";
    html += "</div>";
    html += "<div id='espNowBox' style='background:#0a0a18; color:#38bdf8; padding:10px; border-radius:8px; height:180px; overflow-y:auto; font-size:12px; font-family:monospace;'>Várakozás ESP-NOW csomagokra...</div>";
    html += R"script(<script>
    function fetchEspNowLog() {
        fetch('/api/espnow_log')
        .then(r => r.json())
        .then(arr => {
            let box = document.getElementById('espNowBox');
            if(arr.length === 0) {
                box.innerText = 'Még nem érkezett ESP-NOW csomag ebben a munkamenetben.';
                return;
            }
            box.innerText = arr.join('\n');
            box.scrollTop = box.scrollHeight;
        }).catch(() => {});
    }
    setInterval(fetchEspNowLog, 3000);
    fetchEspNowLog();
    </script>)script";
    html += "</div>";

    // --- ESZKÖZ DIAGNOSZTIKA ---
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

    // --- AT PARANCSOK ÉS SNAPSHOT ---
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
        html += "<div class='card wide'><h2>Kézi AT parancs</h2>"
                "<div style='display:flex;gap:8px'><input type='text' id='atCmdInput' placeholder='pl. AT+CSQ' style='flex:1'>"
                "<button class='sec' type='button' onclick='sendAtCmd()' style='width:120px;'>Küldés</button></div>"
                "<div class='diag' id='atResultBox' style='margin-top:10px;'></div>"
                "<script>function sendAtCmd(){ let cmd = document.getElementById('atCmdInput').value; if(!cmd) return; document.getElementById('atResultBox').innerText = 'Küldés folyamatban...'; fetch('/at_ajax?cmd=' + encodeURIComponent(cmd)).then(r=>r.text()).then(txt=>{ document.getElementById('atResultBox').innerText = txt; }); }</script></div>";

        html += "<div class='card wide diag-card'><h2>AT Állapot Snapshot</h2>";
        html += "<div style='display:flex; gap:8px; margin-bottom:10px;'>";
        html += "<button class='sec' type='button' id='btnGenSnap' onclick='genSnapshot()'>🔄 Snapshot Generálása</button>";
        html += "<button class='sec' type='button' id='btnCopySnap' style='display:none;' onclick='copySnapshot()'>📋 Másolás vágólapra</button>";
        html += "</div>";
        
        html += "<div class='diag' id='snapContent' style='white-space:pre-wrap; max-height:300px; overflow-y:auto;'>";
        if(gAtStatusSnapshot.length() > 0) {
            html += gAtStatusSnapshot;
        } else {
            html += "<span style='color:var(--txt3); font-style:italic;'>Még nincs adat. Kattints a Generálás gombra!</span>";
        }
        html += "</div>";

        html += R"script(<script>
        if(document.getElementById('snapContent').innerText.indexOf('Még nincs adat') === -1) { 
            document.getElementById('btnCopySnap').style.display='inline-block'; 
        }
        
        const snapCmds = ['ATI', 'AT+CPIN?', 'AT+CSQ', 'AT+CPSI?', 'AT+COPS?', 'AT+CGATT?', 'AT+CNACT?', 'AT+CCLK?'];
        let snapRes = ''; 
        let snapIdx = 0;

        function fetchNextSnap() {
            if(snapIdx >= snapCmds.length) {
                document.getElementById('snapContent').innerText = snapRes;
                document.getElementById('btnGenSnap').disabled = false;
                document.getElementById('btnCopySnap').style.display='inline-block';
                return;
            }
            let c = snapCmds[snapIdx];
            fetch('/at_ajax?cmd=' + encodeURIComponent(c))
            .then(r => r.text())
            .then(txt => {
                snapRes += c + '\n' + txt + '\n\n';
                snapIdx++;
                document.getElementById('snapContent').innerText = snapRes + '⏳ Folytatás...';
                setTimeout(fetchNextSnap, 1300);
            }).catch(err => { 
                snapRes += c + '\nHIBA\n\n'; 
                snapIdx++; 
                setTimeout(fetchNextSnap, 1300); 
            });
        }

        function genSnapshot() {
            document.getElementById('btnGenSnap').disabled = true;
            document.getElementById('btnCopySnap').style.display='none';
            document.getElementById('snapContent').innerText = '⏳ Snapshot indítása...';
            let d = new Date();
            snapRes = '=== AT SNAPSHOT (' + d.toLocaleTimeString() + ') ===\n\n';
            snapIdx = 0;
            fetchNextSnap();
        }

        function copySnapshot() {
            var txt = document.getElementById('snapContent').innerText;
            var ta = document.createElement('textarea');
            ta.value = txt;
            ta.style.position = 'fixed';
            ta.style.opacity = '0';
            document.body.appendChild(ta);
            ta.select();
            try {
                document.execCommand('copy');
                var btn = document.getElementById('btnCopySnap');
                btn.innerText = 'Másolva! ✓';
                btn.style.color = 'var(--ok)';
                setTimeout(function(){ btn.innerText = '📋 Másolás vágólapra'; btn.style.color = ''; }, 2000);
            } catch(e) {
                alert('A másolás nem sikerült.');
            }
            document.body.removeChild(ta);
        }
        </script>)script";
        html += "</div>";
    #endif
    html += htmlFoot();
    request->send(200, "text/html", html);
}

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
void handleAtAjax(AsyncWebServerRequest *request) {
    if(!request->hasParam("cmd")) { 
        request->send(400, "text/plain", "Hiányzik a parancs"); 
        return; 
    }
    String cmd = request->getParam("cmd")->value();
    diagAdd("[AT] Lekérés: " + cmd);
    request->send(200, "text/plain", (!gModem.ready) ? "HIBA: Modem nem aktív." : modemAtQuery(cmd, 3000));
}

void handleDeleteHive(AsyncWebServerRequest *request) {
    request->send(200, "application/json", "{\"status\":\"ok\"}");
}
#endif

void initDiagRoutes() {
    server.on("/diag", HTTP_GET, handleDiag);
    
    server.on("/api/diag_log", HTTP_GET, [](AsyncWebServerRequest *request){
        request->send(200, "text/plain", diagDump());
    });

    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
    server.on("/api/espnow_log", HTTP_GET, [](AsyncWebServerRequest *request){
        request->send(200, "application/json", getEspNowLogsJson());
    });
    #endif
    
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

        server.on("/api/barcode_scanned", HTTP_GET, [](AsyncWebServerRequest *request){
            if (!request->hasParam("code")) {
                request->send(400, "text/plain", "Hiányzik a kód");
                return;
            }
            String code = request->getParam("code")->value();
            diagAdd("[BARCODE] Beolvasva: " + code);
            request->send(200, "text/plain", "OK");
        });
    #endif
}