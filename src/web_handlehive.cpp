#include "config.h"
#include <Arduino.h>
#include <Preferences.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <ESPAsyncWebServer.h>
#include "web_handlehive.h"
#include "web_common.h"
#include "web_theme.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  extern bool checkPinGuard(AsyncWebServerRequest *request);
#else
  bool checkPinGuard(AsyncWebServerRequest *request) { return true; }
#endif

void handleHiveView(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "A1B2";
  
  int queenYear = 2023;
  int batPct = 90;
  String monStat = "OK";

  String famStatus = "Rendben, Erős";
  String interventionText = "Rendben";
  String boxClass = "b-grn";
  String box2Class = "b-grn";
  String box1Class = "b-grn";
  String broodUpClass = "b-grn";
  String broodLowClass = "b-grn";

  if (hiveId == "A1B2") {
    famStatus = "Rendben, Erős";
    interventionText = "Rendben";
  } else if (hiveId == "B3C4") {
    famStatus = "Fejlesztés alatt";
    interventionText = "5 nap múlva";
    boxClass = "b-yell"; box2Class = "b-yell";
  } else if (hiveId == "DEAD") {
    famStatus = "Kritikus probléma";
    interventionText = "🔥 Hans";
    boxClass = "b-flame"; box2Class = "b-flame"; box1Class = "b-flame"; broodUpClass = "b-flame"; broodLowClass = "b-flame";
  }

  bool isHans = (hiveId == "DEAD");

  String html = htmlHead("Kaptár: " + hiveId, "11");

  html += "<style>"
          "@keyframes flammenwerfer { 0% { opacity: 1; background-color: rgba(255,0,0,0.3); } 50% { opacity: 0.4; background-color: rgba(255,0,0,0.8); } 100% { opacity: 1; background-color: rgba(255,0,0,0.3); } }"
          ".hive-stack { display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 12px; background: #0a0a18; border-radius: 12px; border: 1px solid var(--border); max-width: 150px; margin: 0 auto; }"
          ".box-super { width: 100%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 11px; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.4); text-align: center; padding: 0 2px; overflow: hidden; }"
          ".box-square { aspect-ratio: 1 / 1; }"
          ".box-ratio-23 { aspect-ratio: 3 / 2; }"
          ".alert-banner { padding: 12px; border-radius: 8px; font-weight: bold; text-align: center; margin-bottom: 16px; font-size: 15px; }"
          ".hans-meme-container { width: 100%; text-align: center; margin-bottom: 14px; }"
          ".hans-meme  { width: 100%; max-width: 380px; height: auto; max-height: 200px; object-fit: contain; border-radius: 8px; border: 2px solid #ef4444; display: inline-block; }"
          ".b-grn   { background: rgba(34,197,94,0.3); color: #22c55e; border: 2px solid #22c55e; }"
          ".b-yell  { background: rgba(234,179,8,0.3); color: #eab308; border: 2px solid #eab308; }"
          ".b-flame { background: rgba(255,0,0,0.6); color: #fff; border: 2px solid #ff3333; animation: flammenwerfer 0.8s infinite; }"
          ".modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); z-index: 1000; justify-content: center; align-items: center; padding: 16px; box-sizing: border-box; }"
          ".modal-content { background: var(--card); border: 1px solid var(--border); border-radius: 16px; padding: 20px; width: 100%; max-width: 450px; max-height: 90vh; overflow-y: auto; }"
          ".modal-btn { display: block; width: 100%; padding: 16px; margin-bottom: 10px; font-size: 18px; font-weight: bold; text-align: left; border-radius: 10px; cursor: pointer; background: #141428; color: var(--txt); border: 1px solid var(--border); }"
          ".modal-btn:hover { background: var(--border); border-color: var(--accent); }"
          ".modal-cat { font-size: 14px; color: var(--accent); text-transform: uppercase; letter-spacing: 1px; margin: 14px 0 6px 0; font-weight: bold; }"
          "</style>";

  html += "<div style='display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; width:100%; margin-bottom:15px; gap:10px;'>";
  html += "<div style='display:flex; align-items:center; gap:10px; width:100%;'><h2 style='margin:0;'>Kaptár:</h2>";
  html += "<select onchange=\"location.href='/hive?hive='+this.value\" style='flex:1; padding:10px; border-radius:8px; background:#141428; color:var(--accent); border:1px solid var(--border); font-size:18px; font-weight:bold; cursor:pointer;'>";
  html += "<option value='A1B2'" + String(hiveId=="A1B2"?" selected":"") + ">A1B2</option>";
  html += "<option value='B3C4'" + String(hiveId=="B3C4"?" selected":"") + ">B3C4</option>";
  html += "<option value='DEAD'" + String(hiveId=="DEAD"?" selected":"") + ">DEAD (Teszt)</option>";
  html += "</select></div>";
  html += "<a href='/hives' style='width:100%;'><button class='sec' style='width:100%; padding:12px; font-size:15px;'>🗺 Vissza a Térképre</button></a></div>";

  html += "<div style='display:grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; width:100%;'>";
  html += "<div style='display:flex; flex-direction:column; gap:16px;'>";

  if (isHans) {
    html += "<div class='alert-banner " + boxClass + "'>🔥 HANS KRITIKUS ÁLLAPOT! 🔥</div>";
    html += "<div class='hans-meme-container'><img src='hans.png' class='hans-meme' alt='Hans'></div>";
  } else {
    html += "<div class='alert-banner " + boxClass + "'>Státusz: " + interventionText + "</div>";
  }

  html += "<div class='card full' style='margin:0;'><h2>🐝 Család Adatok</h2>";
  html += stateRow("👑 Anya évjárat", String(queenYear), "y");
  html += stateRow("Család Állapota", famStatus, "");
  html += "<div class='row'><span class='k'>Funkció / Típus</span><span class='v' id='colony-func-display' style='color:var(--accent);'>Betöltés...</span></div>";
  html += "<button class='sec' style='margin-top:10px; padding:8px; font-size:13px;' onclick='selectColonyFunction()'>⚙️ Funkció módosítása</button></div>";

  html += "<div class='card full' style='margin:0;'><h2>📡 Telemetria</h2>";
  html += stateRow("Akku", String(batPct) + "%", batPct > 20 ? "g" : "r");
  html += stateRow("Monitor", monStat, "g");
  html += "</div>";

  html += "<div style='display:flex; gap:10px; margin-bottom:10px;'>";
  html += "<button class='warn' style='flex:1; padding:14px; font-size:16px;' onclick=\"location.href='/treatment?hive=" + hiveId + "'\">📝 Kezelés</button>";
  html += "<button class='warn' style='flex:1; padding:14px; font-size:16px; background:rgba(34,197,94,0.2); border-color:#22c55e; color:#22c55e;' onclick=\"location.href='/evaluation?hive=" + hiveId + "'\">📊 Értékelés</button></div>";
  html += "<button class='sec' style='width:100%; padding:14px; font-size:16px;' onclick=\"location.href='/config?hive=" + hiveId + "'\">⚙️ Konfig</button></div>"; 

  html += "<div class='card full' style='margin:0;'><h2>📦 Kaptár Állapot</h2>";
  html += "<div class='hive-stack'>";
  html += "<div class='box-super box-ratio-23 " + box2Class + "'>Méztér 2</div>";
  html += "<div class='box-super box-ratio-23 " + box1Class + "'>Méztér 1</div>";
  html += "<div class='box-super box-square " + broodUpClass + "'>Fészek (Felső)</div>";
  html += "<div class='box-super box-square " + broodLowClass + "'>Fészek (Alsó)</div>";
  html += "<div style='width:100%; height:10px; background:#444; border-radius:2px; margin-top:3px;'></div>";
  html += "</div></div></div>"; 

  html += "<div id='colonyModal' class='modal-overlay'><div class='modal-content'>";
  html += "<h2 style='margin-bottom:12px;'>Család funkció kiválasztása</h2><div id='modal-body'></div>";
  html += "<button class='sec' style='margin-top:15px; padding:14px; font-size:16px;' onclick='closeColonyModal()'>Mégse</button></div></div>";

  html += "<script>"
          "let colonyData = null;"
          "fetch('/api/colony_functions').then(r => r.json()).then(data => { colonyData = data; document.getElementById('colony-func-display').innerText = 'Termelő: Méz'; }).catch(e => { document.getElementById('colony-func-display').innerText = 'N/A'; });"
          "function selectColonyFunction() {"
          "  if (!colonyData || !colonyData.colony_functions) return;"
          "  let body = document.getElementById('modal-body'); body.innerHTML = '';"
          "  colonyData.colony_functions.forEach(cat => {"
          "    let catHeader = document.createElement('div'); catHeader.className = 'modal-cat'; catHeader.innerText = cat.name; body.appendChild(catHeader);"
          "    cat.types.forEach(t => {"
          "      let btn = document.createElement('button'); btn.className = 'modal-btn'; btn.innerText = t;"
          "      btn.onclick = function() { let finalVal = cat.name + ': ' + t; alert('Mentve: ' + finalVal); document.getElementById('colony-func-display').innerText = finalVal; closeColonyModal(); };"
          "      body.appendChild(btn);"
          "    }); }); document.getElementById('colonyModal').style.display = 'flex';"
          "} function closeColonyModal() { document.getElementById('colonyModal').style.display = 'none'; }</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleNfc(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String html = htmlHead("NFC Olvasás", "1");
  html += "<div class='card wide'><h2>📱 NFC / RFID Olvasás</h2><p class='hint'>Kérlek, érints a leolvasóhoz egy NFC kártyát vagy kaptár címkét...</p>";
  html += "<div style='text-align:center; padding:30px; color:var(--accent);'><p style='font-weight:bold; margin-top:10px;'>Várakozás NFC jelre...</p></div>";
  html += "<button class='sec' style='width:100%; margin-top:15px;' onclick=\"location.href='/'\">⬅ Vissza a Főoldalra</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleMapStatusApi(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String json = "{\"signal\":-68,\"fix\":true,\"sat\":\"5 (3D)\",\"uptime\":120,\"heap\":150,\"markers\":[]}";
  request->send(200, "application/json", json);
}

void handleTreatment(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "A1B2";

  String html = htmlHead("Kezelés rögzítése: " + hiveId, "11");
  html += "<style>.treatment-container { max-width: 600px; margin: 0 auto; }</style>";
  html += "<div class='card wide treatment-container'><h2>📝 Kezelés rögzítése - Kaptár: " + hiveId + "</h2><p class='hint'>Adatok betöltése a szerverről...</p><div id='treatment-root'></div>";
  html += "<script>fetch('/api/treatments').then(r => r.json()).then(data => { document.getElementById('treatment-root').innerHTML = 'Betöltve (Minta JSON mappa hiányzik a valós adathoz)'; }).catch(e => { document.getElementById('treatment-root').innerHTML = '<div class=\"msg err\">Hiba a kezelések betöltésekor.</div>'; });</script>";
  html += "<button class='sec' style='margin-top:20px; padding:16px; font-size:16px; width:100%;' onclick=\"location.href='/hive?hive=" + hiveId + "'\">⬅ Vissza a kaptárhoz</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleConfig(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "A1B2";

  String html = htmlHead("Konfig: " + hiveId, "4");
  
  // Betöltjük a html5-qrcode könyvtárat
  html += "<script src=\"https://unpkg.com/html5-qrcode\"></script>";

  html += "<div class='card wide'><h2>Kaptár Konfiguráció - " + hiveId + "</h2>";
  html += "<p class='hint' style='margin-bottom:15px;'>Indítsd el az élő szkennert. Ha sötét van, a vaku gombbal felkapcsolhatod a LED-et.</p>";
  
  html += "<div style='background:rgba(255,255,255,0.03); border:1px solid var(--border); border-radius:12px; padding:16px; margin-bottom:20px; text-align:center;'>";
  html += "<h3 style='font-size:15px; margin-bottom:8px;'>📷 Élő Vonalkód / QR Olvasó</h3>";
  
  // A kamera megjelenítő ablaka
  html += "<div id='reader' style='width:100%; max-width:320px; margin:0 auto; border-radius:8px; overflow:hidden;'></div>";
  
  html += "<button type='button' id='startBtn' class='pri' style='margin-top:12px; width:100%; padding:14px; font-size:16px; background:var(--accent); border:none; border-radius:8px; cursor:pointer; color:#fff;' onclick='startScanner()'>▶ Kamera indítása</button>";
  
  // Vezérlőgombok (Vaku és Leállítás), amik csak a kamera indulása után látszanak
  html += "<div id='controls' style='display:none; display:flex; gap:8px; margin-top:12px;'>";
  html += "<button type='button' id='torchBtn' class='sec' style='flex:1; padding:12px; font-size:14px; background:#eab308; color:#000; font-weight:bold; border:none; border-radius:8px; cursor:pointer;' onclick='toggleTorch()'>🔦 Vaku: KI</button>";
  html += "<button type='button' class='sec' style='flex:1; padding:12px; font-size:14px; border-radius:8px; cursor:pointer;' onclick='stopScanner()'>⏹ Leállítás</button>";
  html += "</div>";

  html += "<div id='scanResult' style='margin-top:12px; font-size:13px; font-weight:bold;'></div>";
  html += "</div>";

  html += R"script(<script>
  let html5QrCode = null;
  let torchEnabled = false;

  function startScanner() {
      document.getElementById('startBtn').style.display = 'none';
      let resBox = document.getElementById('scanResult');
      resBox.style.color = 'var(--accent)';
      resBox.innerText = 'Kamera indítása...';

      html5QrCode = new Html5Qrcode("reader");
      
      const config = { fps: 10, qrbox: { width: 250, height: 150 } };
      
      html5QrCode.start(
          { facingMode: "environment" }, 
          config, 
          (decodedText, decodedResult) => {
              // Sikeres olvasás!
              resBox.style.color = 'var(--ok)';
              resBox.innerText = 'Megvan: ' + decodedText + ' -> Küldés...';
              stopScanner();
              
              fetch('/api/barcode_scanned?code=' + encodeURIComponent(decodedText))
              .then(r => r.text())
              .then(res => {
                  resBox.innerText = 'Siker! Átküldve a terminálnak.';
              })
              .catch(err => {
                  resBox.style.color = 'var(--err)';
                  resBox.innerText = 'Hiba a küldéskor: ' + err;
              });
          },
          (errorMessage) => {
              // Keresési fázis (folyamatosan fut, nem kell kiírni hibát)
          }
      ).then(() => {
          document.getElementById('controls').style.display = 'flex';
          resBox.innerText = 'Keresd a kódet a keretben...';
      }).catch(err => {
          resBox.style.color = 'var(--err)';
          resBox.innerText = 'Kamera hiba (Lehet, hogy a böngésző tiltja HTTP-n): ' + err;
          document.getElementById('startBtn').style.display = 'block';
      });
  }

  function toggleTorch() {
      if (!html5QrCode) return;
      torchEnabled = !torchEnabled;
      
      html5QrCode.applyVideoConstraints({
          advanced: [{ torch: torchEnabled }]
      }).then(() => {
          let btn = document.getElementById('torchBtn');
          if (torchEnabled) {
              btn.innerText = '🔦 Vaku: BE';
              btn.style.background = '#22c55e';
              btn.style.color = '#fff';
          } else {
              btn.innerText = '🔦 Vaku: KI';
              btn.style.background = '#eab308';
              btn.style.color = '#000';
          }
      }).catch(err => {
          torchEnabled = !torchEnabled;
          alert('Ez a böngésző vagy eszköz nem támogatja a szoftveres vakukezelést.');
      });
  }

  function stopScanner() {
      if (html5QrCode) {
          if (torchEnabled) {
              html5QrCode.applyVideoConstraints({ advanced: [{ torch: false }] }).catch(()=>{});
              torchEnabled = false;
          }
          html5QrCode.stop().then(() => {
              document.getElementById('startBtn').style.display = 'block';
              document.getElementById('controls').style.display = 'none';
              document.getElementById('scanResult').innerText = '';
          }).catch(err => {
              console.error("Leállítási hiba", err);
          });
      }
  }
  </script>)script";

  html += "<button class='sec' style='width:100%; padding:14px; font-size:16px;' onclick=\"location.href='/hive?hive=" + hiveId + "'\">⬅ Vissza a kaptárhoz</button>";
  html += "</div>";
  
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleConfigPost(AsyncWebServerRequest *request) {
  request->redirect("/hives");
}

void handleRegisterPart(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  request->send(200, "text/html", htmlHead("Alkatrész", "4") + "<div class='card wide'><h2>Alkatrész Regisztráció</h2><p>Még fejlesztés alatt.</p></div>" + htmlFoot());
}

void handleRegisterPartPost(AsyncWebServerRequest *request) {
  request->redirect("/hives");
}

void handleGetTreatmentsJson(AsyncWebServerRequest *request) {
  if (!LittleFS.exists("/treatment.json")) {
    request->send(404, "application/json", "{\"error\":\"treatment.json not found\"}");
    return;
  }
  request->send(LittleFS, "/treatment.json", "application/json");
}

void handleEvaluatePost(AsyncWebServerRequest *request) {
  request->redirect("/hives");
}

void handleGetEvaluationsJson(AsyncWebServerRequest *request) {
  if (!LittleFS.exists("/evaluation.json")) {
    request->send(404, "application/json", "{\"error\":\"evaluation.json not found\"}");
    return;
  }
  request->send(LittleFS, "/evaluation.json", "application/json");
}

void handleEvaluation(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "A1B2";
  String html = htmlHead("Értékelés: " + hiveId, "11");
  html += "<div class='card wide eval-container'><h2>📊 Értékelés - Kaptár: " + hiveId + "</h2><p class='hint'>Adatok betöltése a szerverről...</p><div id='eval-root'></div>";
  html += "<button class='sec' style='margin-top:20px; padding:16px; font-size:16px; width:100%;' onclick=\"location.href='/hive?hive=" + hiveId + "'\">⬅ Vissza a kaptárhoz</button></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleGetColonyFunctionsJson(AsyncWebServerRequest *request) {
  if (!LittleFS.exists("/colony_functions.json")) {
    request->send(404, "application/json", "{\"error\":\"colony_functions.json not found\"}");
    return;
  }
  request->send(LittleFS, "/colony_functions.json", "application/json");
}

void handlePostQueenRearing(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  request->send(200, "application/json", "{\"status\":\"ok\"}");
}

void handleGetDiseasesJson(AsyncWebServerRequest *request) {
  if (!LittleFS.exists("/diseases.json")) {
    request->send(404, "application/json", "{\"error\":\"diseases.json not found\"}");
    return;
  }
  request->send(LittleFS, "/diseases.json", "application/json");
}