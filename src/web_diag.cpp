#include "config.h"
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <ESPAsyncWebServer.h>
#include <WiFi.h>
#include <Wire.h>
#include "server_comm.h"
#include "web_diag.h"
#include "web_theme.h"
#include "web_common.h"
#include "ota_mgr.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  #include "modem_mgr.h"
  #include "time_mgr.h"
  extern ModemState gModem;
  extern TimeState gTime;
  extern String gAtStatusSnapshot;
  extern String getEspNowLogsJson(); 
#endif

extern AsyncWebServer server;

void handleSaveOtaConfig(AsyncWebServerRequest *request) {
    bool enabled = request->hasParam("ota_en", true);
    String ssid = gMonitorOtaSsid;
    String pass = gMonitorOtaPass;
    String url  = gMonitorOtaUrl;

    if (request->hasParam("ota_ssid", true)) {
        ssid = request->getParam("ota_ssid", true)->value();
        ssid.trim();
    }
    if (request->hasParam("ota_pass", true)) {
        pass = request->getParam("ota_pass", true)->value();
        pass.trim();
    }
    if (request->hasParam("ota_url", true)) {
        url = request->getParam("ota_url", true)->value();
        url.trim();
    }

    saveMonitorOtaConfig(enabled, ssid, pass, url);

    diagAdd(String("[OTA] Kaptármonitor frissítési mód: ") + (gMonitorOtaEnabled ? ("AKTÍV (AP: " + gMonitorOtaSsid + ")") : "KIKAPCSOLVA"));
    request->redirect("/diag");
}

void handleDiag(AsyncWebServerRequest *request) {
    loadMonitorOtaConfig();
    String html = htmlHead("Diagnosztika", "5");
    
    // --- 1. KAPTÁRMONITOR ÉS FLUTTER HOTSPOT OTA BEÁLLÍTÁSOK ---
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
    html += "<div class='card wide'><h2>🚀 Kaptármonitor & Hotspot Firmware Frissítés (OTA)</h2>";
    html += "<p class='hint'>Ha be van jelölve, a fizikai mozgatásra/kopogtatásra (riasztással) ébredő kaptármonitorok megkapják az AP adatokat, és letöltik az új firmware-t a Flutter appból. Az időzítéssel ébredők nem frissülnek.</p>";
    html += "<form action='/api/save_ota_cfg' method='POST'>";
    
    html += "<div class='cb-row' style='margin-bottom:12px;'>";
    html += "<input type='checkbox' id='otaEnCb' name='ota_en' value='1' onchange='toggleOtaFields()'" + String(gMonitorOtaEnabled ? " checked" : "") + ">";
    html += "<label for='otaEnCb' style='font-weight:bold; color:var(--accent); cursor:pointer;'>Firmware frissítés engedélyezése (kopogtatásra ébredő monitoroknak)</label>";
    html += "</div>";

    html += "<div id='otaFields' style='display:" + String(gMonitorOtaEnabled ? "block" : "none") + "; border-top:1px solid var(--border); padding-top:12px; margin-top:8px;'>";
    html += "<label>Telefon Hotspot SSID (Access Point):</label>";
    html += "<input type='text' name='ota_ssid' value='" + htmlEscape(gMonitorOtaSsid) + "' placeholder='pl. Balazs_Phone_AP'>";
    
    html += "<label>Hotspot Jelszó:</label>";
    html += "<input type='text' name='ota_pass' value='" + htmlEscape(gMonitorOtaPass) + "' placeholder='Jelszó (min. 8 karakter)'>";

    html += "<label>Kaptármonitor Firmware URL (Flutter App HTTP szerver címe):</label>";
    html += "<input type='text' name='ota_url' value='" + htmlEscape(gMonitorOtaUrl) + "' placeholder='http://192.168.43.1:8080/firmware.bin'>";
    html += "</div>";

    html += "<div style='display:flex; gap:10px; flex-wrap:wrap; margin-top:10px;'>";
    html += "<button type='submit' class='pri' style='flex:1;'>💾 OTA Beállítások Mentése</button>";
    html += "<button type='button' class='warn' style='flex:1;' onclick='pullServerFwFromApp()'>📲 Szerver Frissítése a Flutter Appból (/server.bin)</button>";
    html += "</div>";
    html += "</form>";
    html += R"script(<script>
    function toggleOtaFields(){
        var cb = document.getElementById('otaEnCb');
        var f = document.getElementById('otaFields');
        if(cb && f) f.style.display = cb.checked ? 'block' : 'none';
    }
    function pullServerFwFromApp(){
        if(!confirm('A szerver most felcsatlakozik a megadott telefonos Hotspotra, letölti a Flutter appból a /server.bin fájlt és újraindul. Folytatod?')) return;
        fetch('/api/server_ota_pull', {method:'POST'}).then(r=>r.text()).then(t=>{
            alert(t);
        });
    }
    </script>)script";
    html += "</div>";
    #endif

    // --- 2. SZERVER SAJÁT FIRMWARE FRISSÍTÉSE (BÖNGÉSZŐS DIREKT FELTÖLTÉS) ---
    html += "<div class='card wide'><h2>📦 Szerver Firmware Frissítés (Kézi fájlfeltöltés)</h2>";
    html += "<p class='hint'>Válaszd ki a szerverhez lefordított <b>.bin</b> fájlt. A feltöltés végén az eszköz automatikusan újraindul.</p>";
    html += "<input type='file' id='srvFwFile' accept='.bin' style='margin-bottom:10px;'>";
    html += "<div id='srvOtaProgWrap' style='display:none; background:#0a0a18; border:1px solid var(--border); border-radius:6px; height:18px; margin-bottom:10px; overflow:hidden;'>";
    html += "<div id='srvOtaBar' style='background:var(--ok); width:0%; height:100%; transition:width 0.2s;'></div></div>";
    html += "<div id='srvOtaStatus' class='hint' style='display:none; font-weight:bold;'></div>";
    html += "<button type='button' class='sec' id='srvOtaBtn' onclick='uploadServerFw()'>⬆️ Fájl Feltöltése és Telepítése</button>";
    html += R"script(<script>
    function uploadServerFw() {
        let fileInput = document.getElementById('srvFwFile');
        if (!fileInput.files.length) { alert('Kérlek válassz ki egy .bin fájlt!'); return; }
        let file = fileInput.files[0];
        if (!confirm('Biztosan frissíted a szerver firmware-t (' + file.name + ')?')) return;

        let btn = document.getElementById('srvOtaBtn');
        let wrap = document.getElementById('srvOtaProgWrap');
        let bar = document.getElementById('srvOtaBar');
        let stat = document.getElementById('srvOtaStatus');

        btn.disabled = true;
        wrap.style.display = 'block';
        stat.style.display = 'block';
        stat.style.color = 'var(--txt)';

        let formData = new FormData();
        formData.append('firmware', file);

        let xhr = new XMLHttpRequest();
        xhr.open('POST', '/api/server_ota', true);
        xhr.upload.onprogress = function(e) {
            if (e.lengthComputable) {
                let pct = Math.round((e.loaded / e.total) * 100);
                bar.style.width = pct + '%';
                stat.innerText = 'Feltöltés és írás a memóriába: ' + pct + '%';
            }
        };
        xhr.onload = function() {
            if (xhr.status === 200) {
                stat.style.color = 'var(--ok)';
                stat.innerText = '✓ Sikeres frissítés! A szerver most újraindul (kb. 10 mp)...';
                setTimeout(() => { location.reload(); }, 10000);
            } else {
                stat.style.color = 'var(--err)';
                stat.innerText = '✗ Hiba: ' + xhr.responseText;
                btn.disabled = false;
            }
        };
        xhr.onerror = function() {
            stat.style.color = 'var(--err)';
            stat.innerText = '✗ Hálózati hiba a feltöltés közben!';
            btn.disabled = false;
        };
        xhr.send(formData);
    }
    </script>)script";
    html += "</div>";

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
    loadMonitorOtaConfig();
    server.on("/diag", HTTP_GET, handleDiag);
    server.on("/api/save_ota_cfg", HTTP_POST, handleSaveOtaConfig);
    
    // Szerver direkt OTA végpont regisztrálása (Multipart file upload)
    server.on("/api/server_ota", HTTP_POST, handleServerOtaResult, handleServerOtaUpload);

    // Szerver Pull-OTA végpont (letöltés a Flutter app :8080/server.bin címéről)
    server.on("/api/server_ota_pull", HTTP_POST, [](AsyncWebServerRequest *request){
        triggerServerPullOta();
        request->send(200, "text/plain", "Szerver OTA letöltés elindítva! Figyeld az Élő Terminált.");
    });

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
            request->send(200, "text/plain", "RS485 Node-ok keresése...\nNode ID: 0x01 (Válaszolt)");
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