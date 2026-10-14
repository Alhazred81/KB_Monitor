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
      for (int i = 0; i < targetHive->honeySupers; i++) {
          boxesHtml += "<div class='box-super box-ratio-23 b-grn' style='font-size:13px;'>Méztér " + String(targetHive->honeySupers - i) + "</div>";
      }

      String funcDisplay = targetHive->function;
      if (funcDisplay.startsWith("Termelő: ")) {
          funcDisplay = funcDisplay.substring(9);
      }

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

      bool pollenEnabled = true;         
      bool pollenNeedsAttention = true;  

      String pollenClass = !pollenEnabled ? "box-pollen pollen-disabled" : (pollenNeedsAttention ? "box-pollen pollen-active" : "box-pollen pollen-idle");
      String pollenStatusText = !pollenEnabled ? "Inaktív" : (pollenNeedsAttention ? "⚠️ Napi felügyelet" : "Rendben");

      boxesHtml += "<div class='" + pollenClass + "'>"
                   "<div style='display:flex; flex-direction:column; gap:2px;'>"
                   "<span style='font-size:13px;'>🌼 Pollengyűjtő</span>"
                   "<span style='font-size:10px; opacity:0.9;'>" + pollenStatusText + "</span>"
                   "</div>"
                   "<button type='button' class='pollen-toggle-btn " + String(pollenEnabled ? "btn-on" : "btn-off") + "' onclick=\"togglePollen('" + hiveId + "', " + (pollenEnabled ? "false" : "true") + ")\">"
                   + String(pollenEnabled ? "BE" : "KI") +
                   "</button>"
                   "</div>";

  } else {
      boxesHtml += "<div class='box-super box-square b-grn'>Nincs adat</div>";
  }

  String html = htmlHead("Kaptár: " + hiveId, "11");

  html += "<style>"
          ".hive-stack { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 14px; background: #0a0a18; border-radius: 12px; border: 1px solid var(--border); max-width: 180px; margin: 0 auto; }"
          ".box-super { width: 100%; display: flex; align-items: center; justify-content: center; font-weight: bold; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.4); text-align: center; padding: 0 4px; overflow: hidden; }"
          ".box-square { aspect-ratio: 1 / 1; }"
          ".box-ratio-23 { aspect-ratio: 3 / 2; }"
          ".box-pollen { width: 100%; min-height: 52px; font-size: 12px; display: flex; justify-content: space-between; align-items: center; padding: 6px 10px; font-weight: bold; border-radius: 6px; border: 2px solid var(--border); box-sizing: border-box; }"
          ".pollen-active { background: rgba(249, 115, 22, 0.3); border-color: #f97316; color: #fdba74; }"
          ".pollen-idle { background: rgba(34, 197, 94, 0.3); border-color: #22c55e; color: #4ade80; }"
          ".pollen-disabled { background: rgba(107, 114, 128, 0.15); border-color: #4b5563; color: #9ca3af; }"
          ".pollen-toggle-btn { padding: 8px 14px; font-size: 13px; font-weight: bold; border-radius: 6px; border: 1px solid rgba(255,255,255,0.3); cursor: pointer; text-transform: uppercase; }"
          ".btn-on { background-color: #16a34a; color: white; }"
          ".btn-off { background-color: #dc2626; color: white; }"
          ".pollen-toggle-btn:hover { filter: brightness(1.2); }"
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
          "}"
          "function togglePollen(hiveId, state) {"
          "  fetch('/api/toggle_pollen?hive=' + hiveId + '&active=' + (state ? '1' : '0'))"
          "  .then(r => r.json())"
          "  .then(d => { location.reload(); });"
          "}"
          "function closeColonyModal() { document.getElementById('colonyModal').style.display = 'none'; }</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
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

// ─── RÖGZÍTÉSI ELOSZTÓ OLDAL ───
void handleRegisterOptions(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  String html = htmlHead("Kaptár Rögzítése", "4");
  html += "<div class='card full'><h2>➕ Új kaptár / eszköz</h2>";
  html += "<p class='hint'>Válaszd ki a rögzítés módját:</p>";

  html += "<div style='display:flex; flex-direction:column; gap:16px; margin-top:20px;'>";
  
  html += "<button class='sec' style='padding:20px; font-size:18px; font-weight:bold; display:flex; align-items:center; gap:12px; justify-content:center;' onclick=\"location.href='/register/qr'\">"
          "📷 QR-kód beolvasása</button>";
          
  html += "<button class='sec' style='padding:20px; font-size:18px; font-weight:bold; display:flex; align-items:center; gap:12px; justify-content:center;' onclick=\"location.href='/nfc'\">"
          "📱 NFC-tag olvasása</button>";
          
  html += "<button class='pri' style='padding:20px; font-size:18px; font-weight:bold; display:flex; align-items:center; gap:12px; justify-content:center;' onclick=\"location.href='/register/manual'\">"
          "⌨️ Kézi bevitel</button>";
          
  html += "</div>";

  html += "<button class='sec' style='margin-top:24px; width:100%; padding:14px; font-size:16px;' onclick=\"location.href='/hives'\">⬅️ Mégse</button>";
  html += "</div>";
  
  html += htmlFoot();
  request->send(200, "text/html", html);
}

// ─── KÉZI BEVITEL ŰRLAP ───
void handleManualAddForm(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String html = htmlHead("Kézi Kaptár Hozzáadás", "4");
  html += "<div class='card full'><h2>Kézi rögzítés</h2>";
  html += "<form action='/api/manual_add' method='POST' style='display:flex; flex-direction:column; gap:12px;'>";
  
  html += "<label>Kaptár ID (pl. KAPTAR-01):</label>";
  html += "<input type='text' name='hive_id' required style='padding:12px; font-size:16px; border-radius:8px;'>";
  
  html += "<label>Kaptármonitor MAC (opcionális):</label>";
  html += "<input type='text' name='mac' placeholder='AA:BB:CC:DD:EE:FF' style='padding:12px; font-size:16px; border-radius:8px;'>";
  
  html += "<label>Anya évjárat:</label>";
  html += "<input type='number' name='queen_year' value='2026' required style='padding:12px; font-size:16px; border-radius:8px;'>";
  
  html += "<label>Funkció:</label>";
  html += "<select name='function' style='padding:12px; font-size:16px; border-radius:8px; background:#141428; color:#fff; border:1px solid var(--border);'>";
  html += "<option value='Termelő'>Termelő</option>";
  html += "<option value='Rajzási'>Rajzási</option>";
  html += "<option value='Anyanevelési Mesterterv'>Anyanevelési Mesterterv</option>";
  html += "<option value='Petés Anyanevelési Mesterterv'>Petés Anyanevelési Mesterterv</option>";
  html += "<option value='Kritikus'>Kritikus</option>";
  html += "</select>";
  
  html += "<button type='submit' class='pri' style='margin-top:20px; padding:16px; font-size:18px;'>💾 Mentés</button>";
  html += "</form>";
  html += "<button class='sec' style='margin-top:16px; width:100%; padding:14px; font-size:16px;' onclick=\"location.href='/register'\">⬅️ Vissza</button>";
  html += "</div>";
  
  html += htmlFoot();
  request->send(200, "text/html", html);
}

// ─── KÉZI BEVITEL MENTÉSE API ───
void handleManualAddPost(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String hiveId = request->hasParam("hive_id", true) ? request->getParam("hive_id", true)->value() : "";
  String mac = request->hasParam("mac", true) ? request->getParam("mac", true)->value() : "";
  int queenYear = request->hasParam("queen_year", true) ? request->getParam("queen_year", true)->value().toInt() : 2026;
  String func = request->hasParam("function", true) ? request->getParam("function", true)->value() : "Termelő";

  if (hiveId.length() > 0) {
    // Csak akkor adjuk hozzá, ha a struktúránkban van még hely
    if (gHiveCount < MAX_HIVES) {
        gHives[gHiveCount].id = hiveId;
        gHives[gHiveCount].macAddress = mac;
        gHives[gHiveCount].queenYear = queenYear;
        gHives[gHiveCount].function = func;
        gHives[gHiveCount].honeySupers = 0;
        gHives[gHiveCount].broodBoxes = 1;
        gHiveCount++;
        
        // Itt majd hívd meg az SQL/mentés függvényt, amint elkészül (pl. hiveDbSave())
    }
    Serial.printf("[REG] Kézi kaptár rögzítve: %s\n", hiveId.c_str());
  }

  request->redirect("/hives");
}

// ─── HELYETTESÍTŐ QR VÉGPONT ───
// ─── HELYETTESÍTŐ QR VÉGPONT ÉS KÉZI/NFC ALTERNATÍVA ───
void handleQrPlaceholder(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  String html = htmlHead("Fiók Olvasása", "4");
  html += "<div class='card full'>";
  html += "<h2 style='display:flex; align-items:center; gap:8px;'>📷 Fészekfiók Azonosítása</h2>";
  html += "<div style='background:rgba(34,197,94,0.15); border:1px solid #22c55e; color:#22c55e; padding:10px; border-radius:8px; margin-bottom:14px; font-weight:bold;'>✓ Rendszer készen áll</div>";
  html += "<p class='hint' style='margin-bottom:16px;'>Olvasd be a fészekfiókon lévő QR vagy vonalkódot a kamerával, vagy használd az alábbi alternatív beviteli módokat:</p>";
  
  // Kamerás gomb (Placeholder / Flutter előkészítés)
  html += "<button class='pri' style='width:100%; padding:16px; font-size:16px; margin-bottom:20px;' onclick=\"alert('A kamerás QR/vonalkód olvasás a jövőbeli mobilalkalmazásban lesz aktív.')\">▶ Kamera indítása</button>";

  // Kézi és NFC alternatív blokk
  html += "<div style='border-top: 1px solid var(--border); padding-top: 15px; margin-top: 10px;'>";
  html += "<p style='font-size:13px; font-weight:bold; color:var(--accent); margin-bottom:10px;'>Vagy azonosítsd be alternatív módon:</p>";
  
  // Kézi bevitel
  html += "<div style='display: flex; gap: 8px; margin-bottom: 12px;'>";
  html += "<input type='text' id='manual-box-id' placeholder='Fiók ID (pl. BOX-003)' style='flex: 1; padding: 12px; background: #141428; color: var(--txt); border: 1px solid var(--border); border-radius: 8px; font-size:14px;'>";
  html += "<button class='pri' style='padding: 0 16px;' onclick='submitManualBox()'>Kézi küldés</button>";
  html += "</div>";

  // NFC UID input
  html += "<div style='display: flex; gap: 8px;'>";
  html += "<input type='text' id='manual-nfc-id' placeholder='NFC UID (pl. 04A1B2C3)...' style='flex: 1; padding: 12px; background: #141428; color: var(--txt); border: 1px solid var(--border); border-radius: 8px; font-size:14px;'>";
  html += "<button class='sec' style='padding: 0 16px;' onclick='submitNfcBox()'>NFC küldés</button>";
  html += "</div>";
  html += "</div>";

  html += "<button class='sec' style='margin-top:20px; width:100%; padding:14px; font-size:16px;' onclick=\"location.href='/hives'\">⬅️ Megszakítás / Vissza</button>";
  html += "</div>";

  // JavaScript a kézi és NFC beküldéshez
  html += "<script>";
  html += "function submitManualBox() {";
  html += "  let id = document.getElementById('manual-box-id').value.trim();";
  html += "  if(id) { window.location.href = '/register/manual?hive_id=' + encodeURIComponent(id); }";
  html += "  else { alert('Kérlek add meg a fiók azonosítóját!'); }";
  html += "}";
  html += "function submitNfcBox() {";
  html += "  let nfc = document.getElementById('manual-nfc-id').value.trim();";
  html += "  if(nfc) {";
  html += "    fetch('/api/inventory').then(r=>r.json()).then(data => {";
  html += "      let found = data.find(item => item.nfc === nfc);";
  html += "      if(found) { alert('NFC Találat: ' + found.id + ' (' + found.type + ')'); }";
  html += "      else { alert('Nincs ilyen NFC UID a raktárkészletben!'); }";
  html += "    }).catch(e => { window.location.href = '/nfc'; });";
  html += "  } else { alert('Kérlek add meg az NFC UID-t!'); }";
  html += "}";
  html += "</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

// ─── ÚJ ESZKÖZ TANULÁSI MÓD API ───
void handleApiStartLearn(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  
  // Itt engedélyezzük az új ESP-NOW eszköz párosítását/fogadását
  Serial.println("[PÁROSÍTÁS] Új kaptármonitor / eszköz tanulási mód aktiválva!");
  
  // Ha van külön logikád a rádió vagy az ESP-NOW párosítási ablak nyitására, azt itt hívhatod meg.
  
  request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Tanulási mód elindítva\"}");
}

// ─── ALKATRÉSZ REGISZTRÁCIÓ (GET) ───
void handleRegisterPart(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String html = htmlHead("Alkatrész Regisztráció", "11");
  html += "<div class='card full'><h2>📦 Új alkatrész / fiók rögzítése</h2>";
  html += "<form action='/register_part_post' method='POST'>";
  
  html += "<div style='margin-bottom:12px;'><label style='display:block; font-size:13px; font-weight:bold; margin-bottom:4px;'>Azonosító (pl. BOX-005):</label>";
  html += "<input type='text' name='id' required style='width:100%; padding:10px; background:#141428; color:var(--txt); border:1px solid var(--border); border-radius:8px;'></div>";
  
  html += "<div style='margin-bottom:12px;'><label style='display:block; font-size:13px; font-weight:bold; margin-bottom:4px;'>Típus:</label>";
  html += "<select name='type' style='width:100%; padding:10px; background:#141428; color:var(--accent); border:1px solid var(--border); border-radius:8px; font-weight:bold;'>";
  html += "<option value='hunor'>Hunor (Normál fiók)</option>";
  html += "<option value='feles'>1/2 NB (Feles fiók)</option>";
  html += "<option value='alj'>Kaptáralj</option>";
  html += "<option value='tetö'>Tetető</option>";
  html += "</select></div>";

  html += "<div style='margin-bottom:12px;'><label style='display:block; font-size:13px; font-weight:bold; margin-bottom:4px;'>Leírás:</label>";
  html += "<input type='text' name='desc' placeholder='pl. 10 keretes Hunor' style='width:100%; padding:10px; background:#141428; color:var(--txt); border:1px solid var(--border); border-radius:8px;'></div>";

  html += "<div style='margin-bottom:16px;'><label style='display:block; font-size:13px; font-weight:bold; margin-bottom:4px;'>NFC UID (Opcionális):</label>";
  html += "<input type='text' name='nfc' placeholder='pl. 04A1B2C3' style='width:100%; padding:10px; background:#141428; color:var(--txt); border:1px solid var(--border); border-radius:8px;'></div>";

  html += "<button type='submit' class='pri' style='width:100%; padding:14px; font-size:16px;'>💾 Alkatrész Mentése</button>";
  html += "</form>";
  html += "<button class='sec' style='width:100%; margin-top:10px; padding:12px;' onclick=\"location.href='/hives'\">⬅️ Vissza</button>";
  html += "</div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

// ─── ALKATRÉSZ MENTÉSE (POST) ───
void handleRegisterPartPost(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String id = request->hasParam("id", true) ? request->getParam("id", true)->value() : "";
  String type = request->hasParam("type", true) ? request->getParam("type", true)->value() : "hunor";
  String desc = request->hasParam("desc", true) ? request->getParam("desc", true)->value() : "";
  String nfc = request->hasParam("nfc", true) ? request->getParam("nfc", true)->value() : "";

  if (id.length() > 0) {
    JsonDocument doc;
    if (LittleFS.exists("/inventory.json")) {
      File f = LittleFS.open("/inventory.json", "r");
      deserializeJson(doc, f);
      f.close();
    }
    
    JsonArray arr = doc.is<JsonArray>() ? doc.as<JsonArray>() : doc.to<JsonArray>();
    JsonObject newPart = arr.add<JsonObject>();
    newPart["id"] = id;
    newPart["type"] = type;
    newPart["desc"] = desc;
    newPart["nfc"] = nfc;

    File f = LittleFS.open("/inventory.json", "w");
    if (f) {
      serializeJson(doc, f);
      f.close();
    }
    Serial.printf("[INVENTORY] Új alkatrész rögzítve: %s (%s)\n", id.c_str(), type.c_str());
  }

  request->redirect("/hives");
}

// ─── NFC OLVASÓ ÉS KERESŐ OLDAL ───
void handleNfc(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String html = htmlHead("NFC Olvasó", "11");
  html += "<div class='card full'><h2>📱 NFC Alkatrész Azonosító</h2>";
  html += "<p class='hint'>Add meg vagy olvasd be az NFC UID-t a raktárkészlet lekérdezéséhez:</p>";
  
  html += "<div style='display:flex; gap:8px; margin-bottom:16px;'>";
  html += "<input type='text' id='nfc-input' placeholder='NFC UID...' style='flex:1; padding:12px; background:#141428; color:var(--txt); border:1px solid var(--border); border-radius:8px;'>";
  html += "<button class='pri' style='padding:0 20px;' onclick='searchNfc()'>Keresés</button>";
  html += "</div>";
  
  html += "<div id='nfc-result' style='background:#141428; padding:14px; border-radius:8px; border:1px solid var(--border); min-height:60px;'>Várakozás azonosítóra...</div>";
  html += "<button class='sec' style='width:100%; margin-top:16px; padding:12px;' onclick=\"location.href='/hives'\">⬅️ Vissza</button>";
  html += "</div>";

  html += "<script>";
  html += "function searchNfc() {";
  html += "  let uid = document.getElementById('nfc-input').value.trim();";
  html += "  if(!uid) return;";
  html += "  fetch('/api/inventory').then(r=>r.json()).then(data => {";
  html += "    let found = data.find(item => item.nfc === uid);";
  html += "    let resDiv = document.getElementById('nfc-result');";
  html += "    if(found) {";
  html += "      resDiv.innerHTML = '<b>Találat:</b> ' + found.id + ' (' + found.type + ') - ' + found.desc;";
  html += "    } else {";
  html += "      resDiv.innerHTML = '<span style=\"color:var(--err)\">Nincs ilyen NFC UID a raktárkészletben. <a href=\"/register_part\" style=\"color:var(--accent)\">Regisztráció?</a></span>';";
  html += "    }";
  html += "  });";
  html += "}";
  html += "</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

// Egyéb segéd- és helyettesítő végpontok
// void handleNfc(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("NFC", "1") + "<div class='card wide'><h2>📱 NFC</h2></div>" + htmlFoot()); }
// void handleRegisterPart(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Alkatrész", "4") + "<div class='card wide'><h2>Alkatrész</h2></div>" + htmlFoot()); }
// void handleRegisterPartPost(AsyncWebServerRequest *request) { request->redirect("/hives"); }
void handleConfig(AsyncWebServerRequest *request) { if (!checkPinGuard(request)) return; request->send(200, "text/html", htmlHead("Konfig", "4") + "<div class='card wide'><h2>⚙️ Konfig</h2></div>" + htmlFoot()); }
void handleConfigPost(AsyncWebServerRequest *request) { request->redirect("/hives"); }
void handleGetTreatmentsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/treatment.json", "application/json"); }
void handleGetEvaluationsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/evaluation.json", "application/json"); }
void handleGetColonyFunctionsJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/colony_functions.json", "application/json"); }
void handleGetDiseasesJson(AsyncWebServerRequest *request) { request->send(LittleFS, "/diseases.json", "application/json"); }