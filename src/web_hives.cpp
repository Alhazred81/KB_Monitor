#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include <LittleFS.h>
#include "gnss_mgr.h"
#include "web_hives.h"
#include "web_common.h"
#include "web_theme.h"
#include "hive_db.h" // <-- Dinamikus adatbázis bevonása

extern bool checkPinGuard(AsyncWebServerRequest *request);

HiveRegistrationContext gRegCtx;

// --- PÁROSÍTÁSI VÁLTOZÓK ---
volatile bool gPairingMode = false;
volatile uint8_t gNewlyPairedMonitorId = 0;
uint32_t gPairingStartTime = 0;

String gRegBoxId = "";
String gRegOriginType = "";
uint8_t gRegMonitorId = 0;

void handleHives(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String html = htmlHead("Kaptárak", "9");

  html += "<style>"
          ".hives-layout { display: grid; grid-template-columns: 1fr; gap: 16px; align-items: start; }"
          "@media(min-width: 1000px) { .hives-layout { grid-template-columns: 1fr 1fr; } }"
          ".col-left { display: flex; flex-direction: column; gap: 16px; }"
          ".col-right { display: flex; flex-direction: column; gap: 16px; height: 100%; }"
          ".telemetry-grid { display: flex; flex-wrap: wrap; gap: 16px; justify-content: space-around; text-align: center; }"
          ".telemetry-item { display: flex; flex-direction: column; align-items: center; justify-content: center; }"
          ".telemetry-label { font-size: 11px; color: var(--txt2); margin-bottom: 4px; text-transform: uppercase; letter-spacing: 1px; }"
          ".telemetry-value { font-size: 15px; font-weight: bold; color: var(--txt); }"
          ".val-ok { color: var(--ok); }"
          ".val-warn { color: var(--warn); }"
          ".val-org { color: #f97316; }"
          ".val-err { color: var(--err); }"
          ".hive-table { width: 100%; border-collapse: collapse; font-size: 13px; }"
          ".hive-table th { text-align: left; padding: 12px 10px; color: var(--txt2); border-bottom: 1px solid var(--border); font-size:12px; text-transform:uppercase; letter-spacing:1px; }"
          ".hive-table td { padding: 12px 10px; border-bottom: 1px solid rgba(255,255,255,0.05); }"
          ".hive-table tr:last-child td { border-bottom: none; }"
          ".hive-table a { color: var(--accent); text-decoration: none; font-weight: bold; font-size: 14px; transition: 0.2s; }"
          ".hive-table a:hover { filter: brightness(1.2); text-decoration: underline; }"
          ".badge { padding: 6px 10px; border-radius: 6px; font-size: 11px; font-weight: bold; text-align: center; display: inline-block; min-width: 90px; }"
          ".b-grn { background: rgba(34,197,94,0.15); color: #22c55e; border: 1px solid #22c55e; }"
          ".b-yell { background: rgba(234,179,8,0.15); color: #eab308; border: 1px solid #eab308; }"
          ".b-org { background: rgba(249,115,22,0.15); color: #f97316; border: 1px solid #f97316; }"
          ".b-red { background: rgba(239,68,68,0.15); color: #ef4444; border: 1px solid #ef4444; }"
          "#map { height: 480px; width: 100%; border-radius: 8px; z-index: 1; border: 1px solid var(--border); }"
          "</style>";

  html += "<link rel=\"stylesheet\" href=\"https://unpkg.com/leaflet@1.9.4/dist/leaflet.css\" />";
  html += "<script src=\"https://unpkg.com/leaflet@1.9.4/dist/leaflet.js\"></script>";

  html += "<div class='hives-layout'>";
  html += "<div class='col-left'>";
  html += "<div class='card full' style='margin:0; padding:16px;'>";
  html += "<div class='telemetry-grid'>";
  html += "<div class='telemetry-item'><span class='telemetry-label'>GSM Térerő</span><span class='telemetry-value' id='tele-gsm'>Frissítés...</span></div>";
  html += "<div class='telemetry-item'><span class='telemetry-label'>GPS Fix</span><span class='telemetry-value' id='tele-gps'>Frissítés...</span></div>";
  html += "<div class='telemetry-item'><span class='telemetry-label'>Uptime</span><span class='telemetry-value' id='tele-up'>Frissítés...</span></div>";
  html += "<div class='telemetry-item'><span class='telemetry-label'>Szabad Memória</span><span class='telemetry-value' id='tele-mem'>Frissítés...</span></div>";
  html += "</div></div>";

  html += "<div class='card full' style='margin:0; padding:16px;'>";
  html += "<h2 style='font-size:15px; margin-bottom:8px;'>🗺 KAPTÁRAK ÉS KÉSZLETEK TÉRKÉPE</h2>";
  html += "<p class='hint' style='margin-bottom:12px;'>Koppints bármelyik elemre a részletekért.</p>";
  html += "<div id='map'></div>";
  html += "</div></div>";

  html += "<div class='col-right'>";
  html += "<div class='card full' style='margin:0; padding:16px; height:100%;'>";
  
  html += "<div style='margin-bottom:16px;'>"
          "<button class='pri' style='width:100%; padding:12px; font-weight:bold; font-size:14px; background:var(--accent); border:none; border-radius:8px; cursor:pointer;' onclick=\"location.href='/reg/start'\">➕ Új kaptár(ak) regisztrációja</button>"
          "</div>";

  html += "<h2 style='font-size:15px; margin-bottom:8px;'>📋 ÁLLAPOT ÉS BEAVATKOZÁSI ÜTEMTERV</h2>";
  html += "<p class='hint' style='margin-bottom:12px;'>Koppints a kaptár azonosítójára a részletes nézethez.</p>";
  
  html += "<div style='overflow-x:auto;'>";
  html += "<table class='hive-table'>";
  html += "<tr><th>Azonosító (MAC)</th><th>Funkció</th><th>Anya</th><th>Státusz</th></tr>";
  
  if (gHiveCount == 0) {
      html += "<tr><td colspan='4' style='text-align:center; padding: 20px;'>Még nincs regisztrált kaptár. Hozz létre egyet a fenti gombbal!</td></tr>";
  } else {
      for (int i = 0; i < gHiveCount; i++) {
          html += "<tr>";
          html += "<td><a href='/hive?hive=" + gHives[i].id + "'>" + gHives[i].id + "</a></td>";
          html += "<td>" + gHives[i].function + "</td>";
          html += "<td>" + String(gHives[i].queenYear) + "</td>";
          html += "<td><span class='badge b-grn'>Aktív</span></td>";
          html += "</tr>";
      }
  }
  html += "</table></div></div></div></div>";

  // JS Térkép inicializálás maximális (21-es) zoommal
  html += "<script>"
          "var map = L.map('map', { maxZoom: 22 }).setView([47.529766, 19.028340], 21);" 
          "L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {attribution: 'Tiles &copy; Esri', maxZoom: 22, maxNativeZoom: 19}).addTo(map);"
          "var customIcon = function(color) { return L.divIcon({ className: 'custom-div-icon', html: '<div style=\"background-color:'+color+'; width:20px; height:20px; border-radius:6px; border:2px solid #fff; box-shadow:0 0 6px rgba(0,0,0,0.6);\"></div>', iconSize: [24, 24], iconAnchor: [12, 12] }); };"
          "var stationIcon = L.divIcon({ className: 'station-icon', html: '<div style=\"background:#4d4dff; padding:5px; border-radius:50%; font-size:16px; text-align:center; border:2px solid #fff; box-shadow: 0 0 10px rgba(77,77,255,0.8); display:flex; align-items:center; justify-content:center; width:30px; height:30px;\">📡</div>', iconSize: [44,44], iconAnchor: [22,22] });"
          "L.marker([47.529850, 19.028340], {icon: stationIcon}).bindPopup('<b>Időjárás-állomás és szerver</b>').addTo(map);" 
          "fetch('/api/map_status').then(r=>r.json()).then(data=>{"
          "  console.log('Térkép adatok érkeztek:', data);"
          "  document.getElementById('tele-gsm').innerHTML = '<span style=\"color:#4d4dff; margin-right:6px; font-size:16px;\">📊</span><span class=\"val-ok\">' + data.signal + ' dBm</span>';"
          "  document.getElementById('tele-gps').innerHTML = data.fix ? '<span class=\"val-ok\">Van (' + data.sat + ')</span>' : '<span class=\"val-err\">Nincs</span>';"
          "  document.getElementById('tele-up').innerHTML = '<b>' + data.uptime + ' perc</b>';"
          "  document.getElementById('tele-mem').innerHTML = '<b>' + data.heap + ' KB</b>';"
          "  if (data.markers && Array.isArray(data.markers) && data.markers.length > 0) {"
          "    data.markers.forEach(item => {"
          "      if (item.type === 'hive') {"
          "        let color = '#22c55e';"
          "        if (item.status === 'warn') color = '#eab308';"
          "        if (item.status === 'org') color = '#f97316';"
          "        if (item.status === 'err' || item.status === 'critical') color = '#ef4444';"
          "        let funcText = item.colonyFunc ? ('<br><span style=\"font-size:11px; color:var(--accent);\">' + item.colonyFunc + '</span>') : '';"
          "        let popupHtml = '<div style=\"text-align:center;\"><b>' + item.id + '</b>' + funcText + '<br><a href=\"/hive?hive=' + encodeURIComponent(item.id) + '\">Részletek megnyitása</a></div>';"
          "        L.marker([item.lat, item.lng], {icon: customIcon(color)}).bindPopup(popupHtml).addTo(map);"
          "      }"
          "    });"
          "  } else {"
          "    console.warn('Figyelem: Nincsenek markerek a JSON-ban! (Vagy üres a gHives tömb)');"
          "  }"
          "}).catch(e=>console.log('Térkép API hiba:', e));"
          "</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

// 1. PÁROSÍTÁS INDÍTÁSA
void handleRegStart(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  gRegCtx.active = true;
  gPairingMode = true; 
  gNewlyPairedMonitorId = 0;
  gPairingStartTime = millis();

  String html = htmlHead("Új Kaptár", "9");
  html += "<div class='card' style='text-align:center;'><h2>📡 Hallgatózás...</h2>";
  html += "<div style='font-size:36px; font-weight:bold; color:var(--accent); margin:10px 0;' id='countdown'>30</div>";
  html += "<p style='font-size:1.1em; color:var(--ok); font-weight:bold;'>Üss rá a kaptármonitor dobozára a felébresztéshez!</p>";
  html += "<p class='hint'>A szerver most 30 másodpercig nyitott, és várja a monitor bejelentkezését.</p>";
  
  html += R"script(<script>
  let timeLeft = 30;
  let pollInterval = setInterval(() => {
      timeLeft--;
      if(timeLeft >= 0) document.getElementById('countdown').innerText = timeLeft;
      
      fetch('/api/check_pairing').then(r=>r.json()).then(d=>{
          if(d.paired) {
              clearInterval(pollInterval);
              window.location.href = '/reg/barcode?monitor_id=' + d.monitor_id;
          } else if(d.timeout || timeLeft <= 0) {
              clearInterval(pollInterval);
              alert("⏳ A párosítási idő lejárt! Nem jelentkezett be új monitor.");
              window.location.href = '/hives';
          }
      }).catch(e => console.error(e));
  }, 1000);
  </script>)script";

  html += "<br><button class='sec' style='width:100%;' onclick=\"location.href='/reg/cancel'\">Mégse</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

// API Végpont: Párosítási státusz JS pollinghoz
void handleCheckPairingAPI(AsyncWebServerRequest *request) {
    if (!gPairingMode && gNewlyPairedMonitorId > 0) {
        String res = "{\"paired\":true, \"monitor_id\":" + String(gNewlyPairedMonitorId) + "}";
        request->send(200, "application/json", res);
        gNewlyPairedMonitorId = 0; 
    } else if (millis() - gPairingStartTime > 30000) { 
        gPairingMode = false; 
        request->send(200, "application/json", "{\"paired\":false, \"timeout\":true}");
    } else {
        request->send(200, "application/json", "{\"paired\":false, \"timeout\":false}");
    }
}

// 2. FÉSZEKFIÓK AZONOSÍTÁSA
void handleRegBarcode(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  if (request->hasParam("monitor_id")) {
      gRegMonitorId = request->getParam("monitor_id")->value().toInt();
  }

  String html = htmlHead("Fiók Olvasása", "9");
  html += "<script src=\"https://unpkg.com/html5-qrcode\"></script>";
  html += "<div class='card wide'><h2>📷 Fészekfiók Azonosítása</h2>";
  html += "<p style='color:var(--ok); font-weight:bold; margin-bottom:10px;'>✅ Monitor csatlakoztatva! (ID: " + String(gRegMonitorId) + ")</p>";
  html += "<p class='hint' style='margin-bottom:15px;'>Olvasd be a fészekfiókon lévő QR vagy vonalkódot.</p>";
  
  html += "<div style='background:rgba(255,255,255,0.03); border:1px solid var(--border); border-radius:12px; padding:16px; text-align:center;'>";
  html += "<div id='reader' style='width:100%; max-width:320px; margin:0 auto; border-radius:8px; overflow:hidden;'></div>";
  html += "<button type='button' id='startBtn' class='pri' style='margin-top:12px; width:100%; padding:14px; font-size:16px;' onclick='startScanner()'>▶ Kamera indítása</button>";
  html += "<div id='scanResult' style='margin-top:12px; font-weight:bold;'></div>";
  html += "</div>";

  html += R"script(<script>
  let html5QrCode = null;
  function startScanner() {
      document.getElementById('startBtn').style.display = 'none';
      let resBox = document.getElementById('scanResult');
      resBox.style.color = 'var(--accent)';
      resBox.innerText = 'Kamera indítása...';

      html5QrCode = new Html5Qrcode("reader");
      html5QrCode.start({ facingMode: "environment" }, { fps: 10, qrbox: { width: 250, height: 150 } }, 
      (decodedText) => {
          resBox.style.color = 'var(--ok)';
          resBox.innerText = 'Megvan: ' + decodedText;
          html5QrCode.stop().then(() => {
              window.location.href = '/reg/queen?barcode=' + encodeURIComponent(decodedText);
          });
      }, 
      (errorMessage) => {}).catch(err => {
          resBox.style.color = 'var(--err)';
          resBox.innerText = 'Kamera hiba: ' + err;
      });
  }
  </script>)script";

  html += "<button class='sec' style='width:100%; margin-top:15px;' onclick=\"location.href='/reg/cancel'\">Megszakítás</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

// 3. ANYA ÉS CSALÁD ADATAI
void handleRegQueen(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;
    
    if (request->hasParam("barcode")) {
        gRegBoxId = request->getParam("barcode")->value();
    }

    String html = htmlHead("Anya Adatai", "9");
    html += "<div class='card'><h2>👑 Anya és Család</h2>";
    html += "<p style='color:var(--ok); font-weight:bold; margin-bottom:15px;'>📦 Fiók rögzítve: " + gRegBoxId + "</p>";
    
    html += "<form action='/reg/survey' method='POST'>";
    
    html += "<label>Anya származása:</label>";
    html += "<input type='text' name='origin' placeholder='Saját nevelés / Tenyésztő neve' style='width:100%; padding:10px; margin-bottom:15px; border-radius:8px;' required>";
    
    html += "<label>Évjárat (szín):</label>";
    html += "<select name='vintage' style='width:100%; padding:10px; margin-bottom:15px; border-radius:8px;'>";
    html += "<option value='2021'>2021 (Fehér)</option>";
    html += "<option value='2022'>2022 (Sárga)</option>";
    html += "<option value='2023'>2023 (Piros)</option>";
    html += "<option value='2024'>2024 (Zöld)</option>";
    html += "<option value='2025'>2025 (Kék)</option>";
    html += "<option value='2026' selected>2026 (Fehér)</option>";
    html += "<option value='2027'>2027 (Sárga)</option>";
    html += "<option value='2028'>2028 (Piros)</option>";
    html += "</select>";

    html += "<label>Család kialakulása:</label>";
    html += "<select name='origin_type' class='sec' style='width:100%; padding:10px; margin-bottom:20px; border-radius:8px;'>";
    html += "<option value='Anyásítás'>Anyásítás (Korábbi család)</option>";
    html += "<option value='Söpört raj'>Söpört raj</option>";
    html += "<option value='Böngészett raj'>Böngészett raj</option>";
    html += "<option value='Természetes raj'>Természetes raj</option>";
    html += "<option value='Műraj'>Műraj</option>";
    html += "</select>";

    html += "<button type='submit' class='pri' style='width:100%; padding:12px;'>Tovább a Helymeghatározáshoz 📍</button></form></div>";
    html += htmlFoot();
    request->send(200, "text/html", html);
}

// 4. GPS BEMÉRÉS
void handleRegSurvey(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  if (request->hasParam("origin", true)) gRegCtx.queenOrigin = request->getParam("origin", true)->value();
  if (request->hasParam("vintage", true)) gRegCtx.queenVintage = request->getParam("vintage", true)->value().toInt();
  if (request->hasParam("origin_type", true)) gRegOriginType = request->getParam("origin_type", true)->value();

  startPreciseSurvey();

  String html = htmlHead("Bemérés", "9");
  html += "<div class='card' style='text-align:center;'><h2>📍 Kaptár Bemérése</h2>";
  html += "<p>Helyezd a telefont / vezérlőt a kaptár tetejére, és <b>ne mozdítsd meg!</b></p>";
  html += "<div style='font-size:36px; font-weight:bold; color:var(--accent); margin:20px 0;' id='countdown'>30</div>";
  html += "<div id='status-text' style='font-size:12px; color:var(--txt2);'>GNSS műholdak keresése...</div>";
  
  html += "<script>"
          "let timer = setInterval(function() {"
          "  fetch('/api/survey_status').then(r => r.json()).then(data => {"
          "    let remaining = Math.round((data.duration - data.elapsed) / 1000);"
          "    if(remaining < 0) remaining = 0;"
          "    document.getElementById('countdown').innerText = remaining;"
          "    document.getElementById('status-text').innerText = 'Minták száma: ' + data.samples + ' | HDOP: ' + data.hdop;"
          "    if(!data.active) { clearInterval(timer); window.location.href = '/reg/summary'; }"
          "  });"
          "}, 1000);"
          "</script>";

  html += "<br><button class='sec' style='width:100%;' onclick=\"location.href='/reg/cancel'\">Megszakítás</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleApiSurveyStatus(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String json = "{";
  json += "\"active\":" + String(gSurvey.active ? "true" : "false") + ",";
  json += "\"elapsed\":" + String(millis() - gSurvey.startTime) + ",";
  json += "\"duration\":" + String(gSurvey.durationMs) + ",";
  json += "\"samples\":" + String(gSurvey.sampleCount) + ",";
  json += "\"hdop\":" + String(gSurvey.bestHdop);
  json += "}";
  request->send(200, "application/json", json);
}

// 5. ÖSSZEGZÉS
void handleRegSummary(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  gRegCtx.finalLat = gSurvey.finalLat;
  gRegCtx.finalLon = gSurvey.finalLon;

  String html = htmlHead("Összegzés", "9");
  html += "<div class='card'><h2>✅ Regisztráció Összegzése</h2>";
  html += "<div style='background:rgba(255,255,255,0.05); padding:15px; border-radius:8px; margin-bottom:15px; font-size:14px; line-height:1.6;'>";
  html += "<b>Monitor ID:</b> " + String(gRegMonitorId) + "<br>";
  html += "<b>Fészekfiók ID:</b> " + gRegBoxId + "<br>";
  html += "<b>Anya:</b> " + gRegCtx.queenOrigin + " (" + String(gRegCtx.queenVintage) + ")<br>";
  html += "<b>Család alapja:</b> " + gRegOriginType + "<br>";
  
  if(gRegCtx.finalLat != 0.0) {
    html += "<b>Pozíció:</b> <span style='color:var(--ok);'>(" + String(gRegCtx.finalLat, 6) + ", " + String(gRegCtx.finalLon, 6) + ")</span>";
  } else {
    html += "<b>Pozíció:</b> <span style='color:var(--err);'>Nem sikerült fogni.</span>";
  }
  html += "</div>";

  html += "<form action='/reg/save' method='POST'><button type='submit' class='pri' style='width:100%; padding:14px; font-size:16px;'>💾 Mentés és Befejezés</button></form>";
  html += "<button class='sec' style='width:100%; margin-top:10px;' onclick=\"location.href='/reg/cancel'\">Mégse (Eldobás)</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

// 6. BEFEJEZÉS
void handleRegSave(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  HiveProfile newHive;
  if(gRegMonitorId == 0) gRegMonitorId = 99;
  
  newHive.id = "24:6F:28:AB:CD:" + String(gRegMonitorId < 10 ? "0" : "") + String(gRegMonitorId);
  
  newHive.monitorId = gRegMonitorId;
  newHive.nfcTag = gRegBoxId;
  
  newHive.queenOrigin = gRegCtx.queenOrigin;
  newHive.queenYear = gRegCtx.queenVintage;
  newHive.originType = gRegOriginType;
  newHive.function = "Termelő: Méz";
  newHive.lat = gRegCtx.finalLat;
  newHive.lon = gRegCtx.finalLon;
  newHive.honeySupers = 2;
  newHive.broodBoxes = 1;

  hiveDbAdd(newHive);

  gRegCtx.active = false;

  String html = htmlHead("Siker", "9");
  html += "<div class='card' style='text-align:center;'><h2>🎉 Kaptár Regisztrálva!</h2>";
  html += "<p>A rendszer elmentette a kaptárt az adatbázisba (ID: <b>" + newHive.id + "</b>).</p>";
  html += "<br><button class='pri' style='width:100%; padding:14px;' onclick=\"location.href='/hives'\">Vissza az Állományhoz</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleRegCancel(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  gRegCtx.active = false;
  gSurvey.active = false;
  gPairingMode = false;
  request->redirect("/hives");
}