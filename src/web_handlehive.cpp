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
      if (gHives[i].id == hiveId) { targetHive = &gHives[i]; break; }
  }
  if (!targetHive && gHiveCount > 0) { targetHive = &gHives[0]; hiveId = targetHive->id; }

  int queenYear = targetHive ? targetHive->queenYear : 2026;
  String famStatus = targetHive ? targetHive->originType : "Ismeretlen";
  String funcText = targetHive ? targetHive->function : "Termelő";
  int batPct = 90;
  String monStat = "OK";
  String boxClass = "b-grn";

  String funcDisplay = funcText;
  if (funcDisplay.startsWith("Termelő: ")) funcDisplay = funcDisplay.substring(9);

  String qColor = "#ffffff";
  switch (queenYear % 10) {
      case 1: case 6: qColor = "#ffffff"; break;
      case 2: case 7: qColor = "#eab308"; break;
      case 3: case 8: qColor = "#ef4444"; break;
      case 4: case 9: qColor = "#22c55e"; break;
      case 5: case 0: qColor = "#3b82f6"; break;
  }

  if (famStatus.indexOf("Rajzási") >= 0) boxClass = "b-yell";
  else if (famStatus.indexOf("Kritikus") >= 0) boxClass = "b-red";
  else if (famStatus.indexOf("Anyátlan") >= 0) boxClass = "b-org";

  String html = htmlHead("Kaptár: " + hiveId, "11");

  html += "<style>"
          ".hive-stack { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 16px; background: #0a0a18; border-radius: 12px; border: 1px solid var(--border); max-width: 260px; margin: 0 auto; }"
          ".stack-row { display: flex; align-items: center; width: 100%; gap: 12px; }"
          ".left-col { flex: 1; display: flex; min-width: 0; }"
          ".right-col { width: 42px; flex-shrink: 0; }"
          ".box-super { width: 100%; box-sizing: border-box; display: flex; align-items: center; justify-content: center; font-weight: bold; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.4); position: relative; }"
          ".box-square { aspect-ratio: 1 / 1; }"
          ".box-pollen { width: 100%; box-sizing: border-box; min-height: 64px; display: flex; flex-direction: row; align-items: center; justify-content: space-between; padding: 12px; font-weight: bold; border-radius: 8px; border: 2px solid var(--border); gap: 10px; }"
          ".pollen-active { background: rgba(249, 115, 22, 0.2); border-color: #f97316; color: #fdba74; }"
          ".pollen-disabled { background: #1f2937 !important; border-color: var(--border) !important; color: var(--txt2) !important; opacity: 0.7; }"
          ".pollen-sw { position: relative; display: inline-block; width: 64px; height: 34px; flex-shrink: 0; }"
          ".pollen-sw input { opacity: 0; width: 0; height: 0; }"
          ".pollen-sl { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: #ef4444; transition: .3s; border-radius: 34px; border: 1px solid rgba(255,255,255,0.1); }"
          ".pollen-sl:before { position: absolute; content: ''; height: 26px; width: 26px; left: 3px; bottom: 3px; background-color: white; transition: .3s; border-radius: 50%; box-shadow: 0 2px 5px rgba(0,0,0,0.4); }"
          ".pollen-sw input:checked + .pollen-sl { background-color: #22c55e; }"
          ".pollen-sw input:checked + .pollen-sl:before { transform: translateX(30px); }"
          ".remove-btn { width: 42px; height: 42px; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: 16px; background: rgba(239,68,68,0.15); border: 1px solid rgba(239,68,68,0.3); border-radius: 8px; transition: 0.2s; }"
          ".remove-btn:hover { background: rgba(239,68,68,0.3); transform: scale(1.05); }"
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

  // Dinamikus, JS alapú Kaptár Építő
  html += "<div class='card full' style='margin:0;'><h2>📦 Kaptár Állapot</h2>";
  html += "<div class='hive-stack' id='hive-stack-container'></div>";
  
  html += "<div id='edit-controls' style='display:none; gap:10px; margin-top:16px;'>";
  html += "<button class='pri' style='flex:1; padding:12px; font-size:15px;' onclick='saveLayout()'>💾 Mentés</button>";
  html += "<button class='sec' style='flex:1; padding:12px; font-size:15px;' onclick='cancelEdit()'>❌ Mégse</button>";
  html += "</div>";
  html += "<button id='btn-edit-mode' class='sec' style='width:100%; padding:12px; font-size:15px; margin-top:16px;' onclick='enterEditMode()'>✏️ Szerkesztés</button>";
  html += "</div>";

  html += "<div class='card full' style='margin:0;'><h2>🐝 Család Adatok</h2>";
  html += stateRow("👑 Anya évjárat", "<span style='color:" + qColor + "; font-weight:bold;'>" + String(queenYear) + "</span>", "");
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

  // Modal a funkcióknak
  html += "<div id='colonyModal' class='modal-overlay'><div class='modal-content'>";
  html += "<h2 style='margin-bottom:12px;'>Család funkció kiválasztása</h2><div id='modal-body'></div>";
  html += "<button class='sec' style='margin-top:15px; padding:14px; font-size:16px;' onclick='closeColonyModal()'>Mégse</button></div></div>";

  // JS Kódinjektálás
  int initSupers = targetHive ? targetHive->honeySupers : 0;
  int initBroods = targetHive ? targetHive->broodBoxes : 1;
  String baseBoxId = targetHive && targetHive->baseBoxId.length() > 0 ? targetHive->baseBoxId : "Nincs";

  html += "<script>\n";
  html += "let hId = '" + hiveId + "';\n";
  html += "let isEditMode = false;\n";
  html += "let layout = { supers: " + String(initSupers) + ", broods: " + String(initBroods) + ", pollen: true, pollenActive: true };\n";
  html += "let origLayout = JSON.parse(JSON.stringify(layout));\n";
  html += "let boxColorClass = '" + boxClass + "';\n";
  html += "let funcDisplay = '" + funcDisplay + "';\n";
  html += "let queenYear = " + String(queenYear) + ";\n";
  html += "let qColor = '" + qColor + "';\n";
  html += "let baseBoxId = '" + baseBoxId + "';\n";

  html += "function renderStack() {\n"
          "  let h = '';\n"
          "  let rowS = \"<div class='stack-row'>\"; let rowE = \"</div>\"; let spc = \"<div class='right-col'></div>\";\n"
          "  if(isEditMode) h += \"<button onclick='layout.supers++; renderStack()' class='sec' style='width:100%; margin-bottom:8px;'>➕ Új Méztér</button>\";\n"
          
          "  for(let i=0; i<layout.supers; i++) {\n"
          "    h += rowS + \"<div class='left-col'><div class='box-super box-square b-grn' style='flex-direction:column;'>\" +\n"
          "         \"<div style='position:absolute; top:6px; left:8px; font-size:9px; opacity:0.6; font-weight:normal;'>ID: Nincs</div>\" +\n"
          "         \"<span>Méztér \" + (layout.supers - i) + \"</span></div></div>\";\n"
          "    if(isEditMode) h += \"<div class='right-col'><div class='remove-btn' onclick='layout.supers--; renderStack()'>❌</div></div>\"; else h += spc;\n"
          "    h += rowE;\n"
          "  }\n"
          
          "  if(isEditMode) h += \"<button onclick='layout.broods++; renderStack()' class='sec' style='width:100%; margin:8px 0;'>➕ Új Fészek</button>\";\n"
          
          "  for(let i=0; i<layout.broods; i++) {\n"
          "    if(i === layout.broods - 1) {\n"
          "      h += rowS + \"<div class='left-col'><div class='box-super box-square \" + boxColorClass + \"' style='flex-direction:column; justify-content:center; gap:4px; padding:6px;'>\" +\n"
          "           \"<div style='position:absolute; top:6px; left:8px; font-size:9px; opacity:0.6; font-weight:normal;'>ID: \" + baseBoxId + \"</div>\" +\n"
          "           \"<div style='position:absolute; top:4px; right:6px; font-size:14px; display:flex; gap:6px; opacity:0.95;'><span>📶</span><span>🔋</span></div>\" +\n"
          "           \"<span style='font-size:12px; opacity:0.95; font-weight:700; text-align:center;'>\" + funcDisplay + \"</span>\" +\n"
          "           \"<span style='display:flex; align-items:center; gap:6px; font-size:13px; font-weight:bold;'>\" +\n"
          "           \"<span style='width:11px; height:11px; background-color:\" + qColor + \"; border-radius:50%; display:inline-block; border:1.5px solid rgba(255,255,255,0.8);'></span>\" + queenYear + \"</span>\" +\n"
          "           \"<span style='font-size:11px; color:var(--accent); margin-top:3px; font-weight:bold; text-align:center;'>Nincs teendő</span></div></div>\" + spc + rowE;\n"
          "    } else {\n"
          "      h += rowS + \"<div class='left-col'><div class='box-super box-square \" + boxColorClass + \"' style='flex-direction:column;'>\" +\n"
          "           \"<div style='position:absolute; top:6px; left:8px; font-size:9px; opacity:0.6; font-weight:normal;'>ID: Nincs</div>\" +\n"
          "           \"<span>Fészek \" + (i + 1) + \"</span></div></div>\";\n"
          "      if(isEditMode) h += \"<div class='right-col'><div class='remove-btn' onclick='if(layout.broods>1) layout.broods--; renderStack()'>❌</div></div>\"; else h += spc;\n"
          "      h += rowE;\n"
          "    }\n"
          "  }\n"
          
          "  if(layout.pollen) {\n"
          "    let pClass = layout.pollenActive ? 'pollen-active' : 'pollen-disabled';\n"
          "    let pText = layout.pollenActive ? '⚠️ Napi felügyelet' : 'Inaktív';\n"
          "    h += rowS + \"<div class='left-col'><div class='box-pollen \" + pClass + \"'>\" +\n"
          "         \"<div style='display:flex; flex-direction:column; justify-content:center;'>\" +\n"
          "         \"<span style='font-size:14px; letter-spacing:0.5px;'>🌼 Pollengyűjtő</span>\" +\n"
          "         \"<span style='font-size:11px; opacity:0.85; margin-top:4px;'>\" + pText + \"</span></div>\" +\n"
          "         \"<label class='pollen-sw'><input type='checkbox' \" + (layout.pollenActive?'checked':'') + \" onchange='togglePol(this.checked)'><span class='pollen-sl'></span></label></div></div>\";\n"
          "    if(isEditMode) h += \"<div class='right-col'><div class='remove-btn' onclick='layout.pollen=false; renderStack()'>❌</div></div>\"; else h += spc;\n"
          "    h += rowE;\n"
          "  } else if(isEditMode) {\n"
          "    h += \"<button onclick='layout.pollen=true; renderStack()' class='sec' style='width:100%; margin:8px 0;'>➕ Pollengyűjtő</button>\";\n"
          "  }\n"
          
          "  h += rowS + \"<div class='left-col'><div style='width:100%; height:12px; background:#333; border-radius:4px; margin-top:2px; box-shadow: 0 4px 6px rgba(0,0,0,0.5);'></div></div>\" + spc + rowE;\n"
          
          "  document.getElementById('hive-stack-container').innerHTML = h;\n"
          "  document.getElementById('edit-controls').style.display = isEditMode ? 'flex' : 'none';\n"
          "  document.getElementById('btn-edit-mode').style.display = isEditMode ? 'none' : 'block';\n"
          "}\n"
          
          "function togglePol(state) { layout.pollenActive = state; if(!isEditMode) fetch('/api/toggle_pollen?hive='+encodeURIComponent(hId)+'&active='+(state?'1':'0')); renderStack(); }\n"
          "function enterEditMode() { isEditMode = true; renderStack(); }\n"
          "function cancelEdit() { layout = JSON.parse(JSON.stringify(origLayout)); isEditMode = false; renderStack(); }\n"
          "function saveLayout() {\n"
          "  fetch('/api/save_layout?hive='+encodeURIComponent(hId)+'&supers='+layout.supers+'&broods='+layout.broods)\n"
          "  .then(r => r.json()).then(d => { origLayout = JSON.parse(JSON.stringify(layout)); isEditMode = false; renderStack(); });\n"
          "}\n"
          "renderStack();\n";

  // Colony Selector JS
  html += "let colonyData = null;"
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
          "}"
          "function closeColonyModal() { document.getElementById('colonyModal').style.display = 'none'; }\n"
          "</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

// ─── ELRENDEZÉS MENTÉSE API ───
void handleSaveLayoutApi(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "";
  int supers = request->hasParam("supers") ? request->getParam("supers")->value().toInt() : 0;
  int broods = request->hasParam("broods") ? request->getParam("broods")->value().toInt() : 1;
  
  for (int i = 0; i < gHiveCount; i++) {
    if (gHives[i].id == hiveId) {
      gHives[i].honeySupers = supers;
      gHives[i].broodBoxes = broods;
      hiveDbSave(); 
      Serial.printf("[NAPLÓ] Kaptár %s felépítése frissítve (Méz: %d, Fészek: %d)\n", hiveId.c_str(), supers, broods);
      break;
    }
  }
  
  request->send(200, "application/json", "{\"status\":\"ok\"}");
}

// ─── KEZELÉSEK OLDAL (/treatment) ───
void handleTreatment(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "";

  String html = htmlHead("Kezelés / Beavatkozás", "11");
  html += "<div class='card full'><h2>📝 Kezelés rögzítése: " + hiveId + "</h2>";
  html += "<p class='hint'>Válassz az alábbi beavatkozások közül:</p>";

  bool loadedFromJson = false;
  if (LittleFS.exists("/treatment.json")) {
    File file = LittleFS.open("/treatment.json", "r");
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, file);
    file.close();

    if (!error && doc["categories"].is<JsonArray>()) {
      loadedFromJson = true;
      JsonArray categories = doc["categories"];
      for (JsonObject cat : categories) {
        String catName = cat["name"];
        html += "<h3 style='color:var(--accent); margin:16px 0 8px 0; font-size:14px; text-transform:uppercase;'>" + catName + "</h3>";
        
        JsonArray items = cat["items"];
        for (JsonObject item : items) {
          String label = item["label"];
          String type = item["type"];
          
          if (type == "prompt") {
            String defVal = item["default"].is<const char*>() || item["default"].is<int>() ? item["default"].as<String>() : "1";
            
            html += "<div style='background:#141428; border:1px solid var(--border); border-radius:10px; padding:12px; margin-bottom:10px;'>";
            html += "<label style='font-weight:bold; color:#fff;'>" + label + "</label>";
            html += "<form action='/treatment/save' method='POST' style='display:flex; gap:8px; margin-top:6px;'>";
            html += "<input type='hidden' name='hive' value='" + hiveId + "'>";
            html += "<input type='hidden' name='action_label' value='" + label + "'>";
            html += "<input type='number' step='0.1' name='amount' value='" + defVal + "' style='margin:0; flex:1;'>";
            html += "<button type='submit' class='pri' style='width:auto; padding:0 16px;'>Mentés</button>";
            html += "</form></div>";

          } else if (type == "alert" || type == "confirm") {
            String confirmText = item["confirmText"].is<const char*>() ? item["confirmText"].as<String>() : "";
            
            html += "<form action='/treatment/save' method='POST' style='margin-bottom:8px;'>";
            html += "<input type='hidden' name='hive' value='" + hiveId + "'>";
            html += "<input type='hidden' name='action_label' value='" + label + "'>";
            
            if (type == "confirm") {
              html += "<button type='submit' class='danger' onclick=\"return confirm('" + confirmText + "');\">" + label + "</button>";
            } else {
              html += "<button type='submit' class='sec'>" + label + "</button>";
            }
            html += "</form>";
          }
        }
      }
    }
  }

  if (!loadedFromJson) {
    html += "<h3 style='color:var(--accent); margin:16px 0 8px 0; font-size:14px;'>🍯 Etetés (Alapértelmezett)</h3>";
    html += "<form action='/treatment/save' method='POST' style='display:flex; gap:8px; margin-bottom:10px;'><input type='hidden' name='hive' value='" + hiveId + "'><input type='hidden' name='action_label' value='Szirup (l)'><input type='number' name='amount' value='1' style='margin:0; flex:1;'><button type='submit' class='pri'>Szirup Mentés</button></form>";
    html += "<form action='/treatment/save' method='POST'><input type='hidden' name='hive' value='" + hiveId + "'><input type='hidden' name='action_label' value='Nosevit'><button type='submit' class='sec'>Nosevit rögzítése</button></form>";
  }

  html += "<button class='sec' style='margin-top:20px;' onclick=\"location.href='/hive?hive=" + hiveId + "'\">⬅️ Vissza a Kaptárhoz</button>";
  html += "</div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleTreatmentPost(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String hiveId = request->hasParam("hive", true) ? request->getParam("hive", true)->value() : "";
  String actionLabel = request->hasParam("action_label", true) ? request->getParam("action_label", true)->value() : "";
  String amount = request->hasParam("amount", true) ? request->getParam("amount", true)->value() : "";

  if (amount.length() > 0) {
    Serial.printf("[NAPLÓ] Kaptár: %s | Akció: %s | Mennyiség: %s\n", hiveId.c_str(), actionLabel.c_str(), amount.c_str());
  } else {
    Serial.printf("[NAPLÓ] Kaptár: %s | Akció: %s\n", hiveId.c_str(), actionLabel.c_str());
  }

  request->redirect("/hive?hive=" + hiveId);
}

// ─── ÉRTÉKELÉS OLDAL (/evaluation) ───
void handleEvaluation(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "";

  String html = htmlHead("Család Értékelése", "11");
  html += "<div class='card full'><h2>📊 Család Értékelés: " + hiveId + "</h2>";
  html += "<p class='hint'>Pontozd a családot a szakmai szempontok szerint:</p>";

  bool loadedFromJson = false;
  if (LittleFS.exists("/evaluation.json")) {
    File file = LittleFS.open("/evaluation.json", "r");
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, file);
    file.close();

    if (!error && doc["categories"].is<JsonArray>() && doc["scale"].is<JsonArray>()) {
      loadedFromJson = true;
      html += "<form action='/evaluation/save' method='POST'>";
      html += "<input type='hidden' name='hive' value='" + hiveId + "'>";

      JsonArray categories = doc["categories"];
      JsonArray scale = doc["scale"];

      for (JsonObject cat : categories) {
        String catName = cat["name"];
        String catId = cat["id"];
        
        html += "<div style='background:#141428; border:1px solid var(--border); border-radius:10px; padding:14px; margin-bottom:14px;'>";
        html += "<h3 style='color:var(--accent); margin-bottom:10px; font-size:15px;'>" + catName + "</h3>";
        
        JsonArray options = cat["options"];
        for (JsonObject opt : options) {
          String optName = opt["name"];
          String optId = opt["id"];
          
          html += "<div style='display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; padding-bottom:6px; border-bottom:1px solid rgba(255,255,255,0.05);'>";
          html += "<span style='font-size:13px; font-weight:600;'>" + optName + "</span>";
          
          html += "<div style='display:flex; gap:6px;'>";
          for (JsonObject sc : scale) {
            String scId = sc["id"];
            String scLabel = sc["label"];
            String fieldName = catId + "_" + optId;
            
            html += "<label style='display:inline-block; cursor:pointer; background:#0a0a18; border:1px solid var(--border); padding:4px 10px; border-radius:6px; text-align:center; min-width:32px; font-weight:bold; font-size:12px;'>";
            html += "<input type='radio' name='" + fieldName + "' value='" + scId + "' style='display:none;' onchange='this.parentNode.style.borderColor=\"var(--accent)\";'>";
            html += scLabel + "</label>";
          }
          html += "</div></div>";
        }
        html += "</div>";
      }

      html += "<button type='submit' class='pri' style='padding:14px; font-size:16px; margin-top:10px;'>💾 Értékelés Mentése</button>";
      html += "</form>";
    }
  }

  if (!loadedFromJson) {
    html += "<p style='color:var(--err);'>Hiba vagy hiányzó evaluation.json, alapértelmezett nézet:</p>";
    html += "<form action='/evaluation/save' method='POST'><input type='hidden' name='hive' value='" + hiveId + "'>";
    html += "<div style='background:#141428; padding:10px; border-radius:8px; margin-bottom:10px;'><p>Szelídség:</p><label><input type='radio' name='behavior_gentle' value='pp'> ++</label> <label><input type='radio' name='behavior_gentle' value='p' checked> +</label></div>";
    html += "<button type='submit' class='pri'>Mentés</button></form>";
  }

  html += "<button class='sec' style='margin-top:15px;' onclick=\"location.href='/hive?hive=" + hiveId + "'\">⬅️ Vissza a Kaptárhoz</button>";
  html += "</div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleEvaluatePost(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String hiveId = request->hasParam("hive", true) ? request->getParam("hive", true)->value() : "";
  Serial.printf("[ÉRTÉKELÉS] Kaptár: %s mentésre került\n", hiveId.c_str());

  request->redirect("/hive?hive=" + hiveId);
}

void handleTogglePollen(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  String hiveId = request->hasParam("hive") ? request->getParam("hive")->value() : "";
  bool active = request->hasParam("active") && request->getParam("active")->value() == "1";

  for (int i = 0; i < gHiveCount; i++) {
    if (gHives[i].id == hiveId) {
      break;
    }
  }

  Serial.printf("[POLLEN] Kaptár %s pollengyűjtő átállítva: %s\n", hiveId.c_str(), active ? "BE" : "KI");
  request->send(200, "application/json", "{\"status\":\"ok\"}");
}

// Egyéb segéd- és helyettesítő végpontok
void handleNfc(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("NFC", "1") + "<div class='card wide'><h2>📱 NFC</h2></div>" + htmlFoot()); }
void handleConfig(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Konfig", "4") + "<div class='card wide'><h2>⚙️ Konfig</h2></div>" + htmlFoot()); }
void handleConfigPost(AsyncWebServerRequest *request) { request->redirect("/hives"); }
void handleRegisterPart(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Alkatrész", "4") + "<div class='card wide'><h2>Alkatrész</h2></div>" + htmlFoot()); }
void handleRegisterPartPost(AsyncWebServerRequest *request) { request->redirect("/hives"); }
void handleGetTreatmentsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/treatment.json", "application/json"); }
void handleGetEvaluationsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/evaluation.json", "application/json"); }
void handleGetColonyFunctionsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/colony_functions.json", "application/json"); }
void handleGetDiseasesJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/diseases.json", "application/json"); }