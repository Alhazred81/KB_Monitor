#include "config.h"
#include <Arduino.h>
#include <Preferences.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <ESPAsyncWebServer.h>
#include "web_handlehive.h"
#include "web_common.h"
#include "web_theme.h"
#include "hive_db.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
  extern bool checkPinGuard(AsyncWebServerRequest *request);
#else
  bool checkPinGuard(AsyncWebServerRequest *request) { return true; }
#endif

void handleMapStatusApi(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  JsonDocument doc;
  doc["signal"] = -68;
  doc["fix"] = true;
  doc["sat"] = "5 (3D)";
  doc["uptime"] = 120;
  doc["heap"] = 150;
  
  JsonArray markers = doc["markers"].to<JsonArray>();

  for (int i = 0; i < gHiveCount; i++) {
      JsonObject marker = markers.add<JsonObject>();
      marker["type"] = "hive";
      marker["id"] = gHives[i].id;
      marker["lat"] = gHives[i].lat;
      marker["lng"] = gHives[i].lon;
      marker["status"] = "ok"; 
      marker["colonyFunc"] = gHives[i].function;
  }

  String json;
  serializeJson(doc, json);
  request->send(200, "application/json", json);
}

void handleHiveView(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "";
  
  HiveProfile* targetHive = nullptr;
  for (int i = 0; i < gHiveCount; i++) {
      if (gHives[i].id == hiveId) {
          targetHive = &gHives[i];
          break;
      }
  }

  if (!targetHive && gHiveCount > 0) {
      targetHive = &gHives[0];
      hiveId = targetHive->id;
  }

  int queenYear = targetHive ? targetHive->queenYear : 2026;
  String famStatus = targetHive ? targetHive->originType : "Ismeretlen";
  String funcText = targetHive ? targetHive->function : "Termelő";
  String taskText = "Nincs teendő"; 
  int batPct = 90;
  String monStat = "OK";
  String boxClass = "b-grn";
  String boxesHtml = "";

  if (targetHive) {
      // Mézterek megjelenítése
      for (int i = 0; i < targetHive->honeySupers; i++) {
          boxesHtml += "<div class='box-super box-ratio-23 b-grn' style='font-size:13px;'>Méztér " + String(targetHive->honeySupers - i) + "</div>";
      }

      // Funkció rövidítése
      String funcDisplay = targetHive->function;
      if (funcDisplay.startsWith("Termelő: ")) {
          funcDisplay = funcDisplay.substring(9);
      }

      // Anya évjárat szín meghatározása
      String qColor = "#ffffff";
      switch (queenYear % 10) {
          case 1: case 6: qColor = "#ffffff"; break;
          case 2: case 7: qColor = "#eab308"; break;
          case 3: case 8: qColor = "#ef4444"; break;
          case 4: case 9: qColor = "#22c55e"; break;
          case 5: case 0: qColor = "#3b82f6"; break;
      }

      String boxColorClass = "b-grn"; 
      if (targetHive->originType.indexOf("Rajzási") >= 0) boxColorClass = "b-yell";
      else if (targetHive->originType.indexOf("Kritikus") >= 0) boxColorClass = "b-red";
      else if (targetHive->originType.indexOf("Anyátlan") >= 0) boxColorClass = "b-org";

      int totalBoxes = targetHive->broodBoxes;
      for (int i = 0; i < totalBoxes; i++) {
          if (i == totalBoxes - 1) {
              boxesHtml += "<div class='box-super box-square " + boxColorClass + "' style='position:relative; display:flex; flex-direction:column; justify-content:center; align-items:center; gap:4px; padding:6px;'>"
                           "<div style='position:absolute; top:4px; right:6px; font-size:14px; display:flex; gap:6px; opacity:0.95;' title='RSSI és Akku'>"
                           "<span>📶</span><span>🔋</span>"
                           "</div>"
                           "<span style='font-size:12px; opacity:0.95; font-weight:700;'>" + funcDisplay + "</span>"
                           "<span style='display:flex; align-items:center; gap:6px; font-size:13px; font-weight:bold;'>"
                           "<span style='width:11px; height:11px; background-color:" + qColor + "; border-radius:50%; display:inline-block; border:1.5px solid rgba(255,255,255,0.8);'></span>"
                           + String(queenYear) + "</span>"
                           "<span style='font-size:11px; color:var(--accent); margin-top:3px; font-weight:bold;'>" + taskText + "</span>"
                           "</div>";
          } else {
              boxesHtml += "<div class='box-super box-square " + boxColorClass + "' style='font-size:13px;'>Fészek " + String(i + 1) + "</div>";
          }
      }

      // --- POLLENGYŰJTŐ FIÓK BEILLESZTÉSE ---
      // Ha a konfiguráció vagy a funkció indokolja, vagy tesztként hozzáadjuk:
      bool hasPollenCollector = (targetHive->function.indexOf("Pollen") >= 0 || hiveId == "H1-TERM");
      if (hasPollenCollector) {
          boxesHtml += "<div class='box-super box-ratio-pollen b-org' style='display:flex; justify-content:space-between; align-items:center; padding:0 8px; font-weight:bold; margin-top:4px;'>"
                       "<span>🌼 Pollengyűjtő</span>"
                       "<span style='font-size:10px; background:rgba(239,68,68,0.2); padding:2px 6px; border-radius:4px; color:#ef4444;'>⚠️ NAPI FELÜGYELET</span>"
                       "</div>";
      }

  } else {
      boxesHtml += "<div class='box-super box-square b-grn'>Nincs adat</div>";
  }

  String html = htmlHead("Kaptár: " + hiveId, "11");

  html += "<style>"
          ".hive-stack { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 14px; background: #0a0a18; border-radius: 12px; border: 1px solid var(--border); max-width: 180px; margin: 0 auto; }"
          ".box-super { width: 100%; display: flex; align-items: center; justify-content: center; font-weight: bold; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.4); text-align: center; padding: 0 4px; overflow: hidden; }"
          ".box-square { aspect-ratio: 1 / 1; }"
          ".box-ratio-23 { aspect-ratio: 3 / 2; }"
          ".box-ratio-pollen { aspect-ratio: 4 / 1; font-size: 11px; background: rgba(249,115,22,0.3); color: #f97316; border: 2px solid #f97316; }"
          ".alert-banner { padding: 12px; border-radius: 8px; font-weight: bold; text-align: center; margin-bottom: 16px; font-size: 15px; }"
          ".b-grn   { background: rgba(34,197,94,0.3); color: #22c55e; border: 2px solid #22c55e; }"
          ".b-yell  { background: rgba(234,179,8,0.3); color: #eab308; border: 2px solid #eab308; }"
          ".b-org   { background: rgba(249,115,22,0.3); color: #f97316; border: 2px solid #f97316; }"
          ".b-red   { background: rgba(239,68,68,0.3); color: #ef4444; border: 2px solid #ef4444; }"
          ".modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); z-index: 1000; justify-content: center; align-items: center; padding: 16px; box-sizing: border-box; }"
          ".modal-content { background: var(--card); border: 1px solid var(--border); border-radius: 16px; padding: 20px; width: 100%; max-width: 450px; max-height: 90vh; overflow-y: auto; }"
          ".modal-btn { display: block; width: 100%; padding: 16px; margin-bottom: 10px; font-size: 18px; font-weight: bold; text-align: left; border-radius: 10px; cursor: pointer; background: #141428; color: var(--txt); border: 1px solid var(--border); }"
          ".modal-btn:hover { background: var(--border); border-color: var(--accent); }"
          ".modal-cat { font-size: 14px; color: var(--accent); text-transform: uppercase; letter-spacing: 1px; margin: 14px 0 6px 0; font-weight: bold; }"
          "</style>";

  html += "<div style='display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; width:100%; margin-bottom:15px; gap:10px;'>";
  html += "<div style='display:flex; align-items:center; gap:10px; width:100%;'><h2 style='margin:0;'>Kaptár:</h2>";
  
  html += "<select onchange=\"location.href='/hive?hive='+encodeURIComponent(this.value)\" style='flex:1; padding:10px; border-radius:8px; background:#141428; color:var(--accent); border:1px solid var(--border); font-size:18px; font-weight:bold; cursor:pointer;'>";
  for (int i = 0; i < gHiveCount; i++) {
      html += "<option value='" + gHives[i].id + "'" + String(gHives[i].id == hiveId ? " selected" : "") + ">" + gHives[i].id + " (" + gHives[i].function + ")</option>";
  }
  html += "</select></div>";
  html += "<a href='/hives' style='width:100%;'><button class='sec' style='width:100%; padding:12px; font-size:15px;'>🗺 Vissza a Térképre</button></a></div>";

  html += "<div style='display:grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; width:100%;'>";
  html += "<div style='display:flex; flex-direction:column; gap:16px;'>";

  html += "<div class='alert-banner " + boxClass + "'>Státusz: Aktív</div>";

  html += "<div class='card full' style='margin:0;'><h2>📦 Kaptár Állapot</h2>";
  html += "<div class='hive-stack'>";
  html += boxesHtml; 
  html += "<div style='width:100%; height:10px; background:#444; border-radius:2px; margin-top:3px;'></div>";
  html += "</div></div>";

  html += "<div class='card full' style='margin:0;'><h2>🐝 Család Adatok</h2>";
  
  String qColorCard = "";
  switch (queenYear % 10) {
      case 1: case 6: qColorCard = "#ffffff"; break;
      case 2: case 7: qColorCard = "#eab308"; break;
      case 3: case 8: qColorCard = "#ef4444"; break;
      case 4: case 9: qColorCard = "#22c55e"; break;
      case 5: case 0: qColorCard = "#3b82f6"; break;
  }
  
  html += stateRow("👑 Anya évjárat", "<span style='color:" + qColorCard + "; font-weight:bold;'>" + String(queenYear) + "</span>", "");
  html += stateRow("Család Állapota", famStatus, "");
  html += "<div class='row'><span class='k'>Funkció / Típus</span><span class='v' id='colony-func-display' style='color:var(--accent);'>" + funcText + "</span></div>";
  html += "<button class='sec' style='margin-top:10px; padding:8px; font-size:13px;' onclick='selectColonyFunction()'>⚙️ Funkció módosítása</button></div>";

  html += "<div class='card full' style='margin:0;'><h2>📡 Telemetria</h2>";
  html += stateRow("Akku", String(batPct) + "%", batPct > 20 ? "g" : "r");
  html += stateRow("Monitor", monStat, monStat == "OK" ? "g" : "r");
  html += "</div>";

  html += "<div style='display:flex; gap:10px; margin-bottom:10px;'>";
  html += "<button class='warn' style='flex:1; padding:14px; font-size:16px;' onclick=\"location.href='/treatment?hive=" + hiveId + "'\">📝 Kezelés</button>";
  html += "<button class='warn' style='flex:1; padding:14px; font-size:16px; background:rgba(34,197,94,0.2); border-color:#22c55e; color:#22c55e;' onclick=\"location.href='/evaluation?hive=" + hiveId + "'\">📊 Értékelés</button></div>";
  html += "<button class='sec' style='width:100%; padding:14px; font-size:16px;' onclick=\"location.href='/config?hive=" + hiveId + "'\">⚙️ Konfig</button></div>"; 

  html += "</div>"; 

  html += "<div id='colonyModal' class='modal-overlay'><div class='modal-content'>";
  html += "<h2 style='margin-bottom:12px;'>Család funkció kiválasztása</h2><div id='modal-body'></div>";
  html += "<button class='sec' style='margin-top:15px; padding:14px; font-size:16px;' onclick='closeColonyModal()'>Mégse</button></div></div>";

  html += "<script>"
          "let colonyData = null;"
          "fetch('/api/colony_functions').then(r => r.json()).then(data => { colonyData = data; }).catch(e => { console.error('Hiba', e); });"
          "function selectColonyFunction() {"
          "  if (!colonyData || !colonyData.colony_functions) return;"
          "  let body = document.getElementById('modal-body'); body.innerHTML = '';"
          "  colonyData.colony_functions.forEach(cat => {"
          "    let catHeader = document.createElement('div'); catHeader.className = 'modal-cat'; catHeader.innerText = cat.name; body.appendChild(catHeader);"
          "    cat.types.format ? '' : cat.types.forEach(t => {"
          "      let btn = document.createElement('button'); btn.className = 'modal-btn'; btn.innerText = t;"
          "      btn.onclick = function() { let finalVal = cat.name + ': ' + t; alert('Mentve: ' + finalVal); document.getElementById('colony-func-display').innerText = finalVal; closeColonyModal(); };"
          "      body.appendChild(btn);"
          "    }); }); document.getElementById('colonyModal').style.display = 'flex';"
          "} function closeColonyModal() { document.getElementById('colonyModal').style.display = 'none'; }</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleNfc(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("NFC", "1") + "<div class='card wide'><h2>📱 NFC</h2></div>" + htmlFoot()); }
void handleTreatment(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Kezelés", "11") + "<div class='card wide'><h2>📝 Kezelés</h2></div>" + htmlFoot()); }
void handleConfig(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Konfig", "4") + "<div class='card wide'><h2>⚙️ Konfig</h2></div>" + htmlFoot()); }
void handleConfigPost(AsyncWebServerRequest *request) { request->redirect("/hives"); }
void handleRegisterPart(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Alkatrész", "4") + "<div class='card wide'><h2>Alkatrész</h2></div>" + htmlFoot()); }
void handleRegisterPartPost(AsyncWebServerRequest *request) { request->redirect("/hives"); }
void handleGetTreatmentsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/treatment.json", "application/json"); }
void handleEvaluatePost(AsyncWebServerRequest *request) { request->redirect("/hives"); }
void handleGetEvaluationsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/evaluation.json", "application/json"); }
void handleEvaluation(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Értékelés", "11") + "<div class='card wide'><h2>📊 Értékelés</h2></div>" + htmlFoot()); }
void handleGetColonyFunctionsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/colony_functions.json", "application/json"); }
void handleGetDiseasesJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/diseases.json", "application/json"); }