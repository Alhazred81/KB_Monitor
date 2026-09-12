#include "web_iot.h"
#include "web_common.h"
#include "config.h"       
#include "modem_mgr.h"    
#include "NtfyClient.h"
#include "time_mgr.h"     
#include "web_theme.h"
#include <EEPROM.h>
#include <ArduinoJson.h>

extern DataConnState gData;
extern TimeState gTime;
extern NtfyClient ntfy;
extern String gNtfyServer;
extern String gNtfyTopic;
extern String gNtfyNickname;
extern bool gNtfyStartupMsg;

extern void saveNtfyConfig(const String& server, const String& topic, const String& nickname, bool startupMsg);
extern String macSuffix();

String gReportTimes = "21:00";
int gLastSentMinute = -1;

void handleIot(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String html = htmlHead("IoT", "3");

  html += "<div class='card'><h2>Adatkapcsolat</h2>";
  html += stateRow("Állapot", gData.active ? "Aktív" : "Inaktív", gData.active ? "g" : "r");
  if (gData.active) html += stateRow("IP cím", gData.ip, "");
  
  html += "<div style='display:flex;gap:8px;margin-top:10px'>";
  if (gData.active) {
    html += "<form action='/dataon' method='POST' style='flex:1'><button class='sec' disabled>Adat be</button></form>";
    html += "<form action='/dataoff' method='POST' style='flex:1'><button class='danger'>Adat ki</button></form>";
  } else {
    html += "<form action='/dataon' method='POST' style='flex:1'><button>Adat be</button></form>";
    html += "<form action='/dataoff' method='POST' style='flex:1'><button class='sec' disabled>Adat ki</button></form>";
  }
  html += "</div></div>";

  html += "<div class='card'><h2>Ping Teszt</h2>";
  html += "<form action='/dataping' method='POST'>";
  html += "<input type='text' name='target' placeholder='IP vagy domain (pl. 8.8.8.8)'>";
  html += "<button class='sec'>Ping indítása</button></form>";
  if (gData.pingResult.length()) html += "<div class='msg " + String(gData.pingOk ? "ok" : "err") + "' style='margin-top:10px'>" + htmlEscape(gData.pingResult) + "</div>";
  html += "</div>";

  html += "<div class='card wide'><h2>📊 Napi Riport Időpontok (ntfy)</h2>"
          "<form action='/save-report' method='POST'>"
          "<label>Riport időpontok (HH:MM formátumban, ;-vel elválasztva)</label>"
          "<input type='text' name='report_times' value='" + (gReportTimes.length() ? gReportTimes : "21:00") + "' placeholder='pl. 08:00; 14:00; 21:00' required>"
          "<p class='hint'>Több időpontot is megadhatsz pontosvesszővel elválasztva.</p>"
          "<button style='margin-top:4px'>Riport Konfig Mentése</button></form>"
          "<form action='/test-report' method='POST' style='margin-top:10px'>"
          "<button class='sec'>🚀 Tesztriport küldése azonnal</button></form></div>";

  html += "<div class='card wide'><h2>ntfy Értesítések</h2>";
  html += "<form action='/ntfy-send' method='POST'>";
  html += "<label>Üzenet küldése</label><input type='text' name='msg' placeholder='Szöveg...' required>";
  html += "<label>Prioritás</label><select name='priority'>"
          "<option value='1'>1 - Min</option><option value='3' selected>3 - Default</option><option value='5'>5 - Max</option></select>";
  html += "<button style='margin-top:8px'>Küldés ntfy-ra</button></form>";
  html += "<hr style='border:0; border-top:1px solid var(--border); margin:15px 0;'>";
  html += "<form action='/ntfy-poll' method='POST'><button class='sec'>Üzenetek lekérdezése (Poll)</button></form>";
  
  if (gData.lastError.length()) {
      if (gData.lastError.startsWith("NTFY_HTML:")) {
          html += "<div class='msg ok' style='margin-top:15px; text-align:left;'>" + gData.lastError.substring(10) + "</div>";
      } else {
          html += "<div class='msg " + String(gData.lastError.startsWith("NTFY") ? "ok" : "err") + "' style='margin-top:10px'>" + htmlEscape(gData.lastError) + "</div>";
      }
  }
  html += "</div>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleNtfySend(AsyncWebServerRequest *request) {
  if(!request->hasParam("msg", true)) { 
    request->redirect("/iot"); return; 
  }
  String msg = request->getParam("msg", true)->value();
  msg.trim();
  int prioVal = request->hasParam("priority", true) ? request->getParam("priority", true)->value().toInt() : 3;
  
  String nick = gNtfyNickname;
  if (nick.length() == 0) nick = "szerver-" + macSuffix();

  bool ok = ntfy.send(msg.c_str(), nick.c_str(), static_cast<NtfyPriority>(prioVal));
  if(ok) diagAdd("ntfy sikeresen elküldve: " + msg);
  else diagAdd("ntfy küldési hiba! HTTP code: " + String(ntfy.getLastHttpCode()));
  
  request->redirect("/iot");
}

void handleNtfyPoll(AsyncWebServerRequest *request) {
  NtfyPollResult res = ntfy.pollMessages("10m", ""); 
  if(res.success) {
    gData.lastError = "NTFY: Üzenetek lekérdezve.";
    diagAdd("ntfy poll sikeres.");
  } else {
    gData.lastError = "NTFY Poll hiba! Kód: " + String(res.httpCode);
    diagAdd("ntfy poll sikertelen.");
  }
  request->redirect("/iot");
}

void handleSaveNtfy(AsyncWebServerRequest *request) {
  if (request->hasParam("ntfy_topic", true)) {
    String srv = request->hasParam("ntfy_server", true) ? request->getParam("ntfy_server", true)->value() : "ntfy.sh";
    String top = request->getParam("ntfy_topic", true)->value();
    String nick = request->hasParam("ntfy_nickname", true) ? request->getParam("ntfy_nickname", true)->value() : "";
    bool startup = request->hasParam("ntfy_startup", true);
    
    srv.trim(); top.trim(); nick.trim();
    saveNtfyConfig(srv, top, nick, startup);
    diagAdd("ntfy konfig mentve.");
  }
  request->redirect("/cfg");
}

void handleDataOn(AsyncWebServerRequest *request) {
  dataConnEnable();
  request->redirect("/iot");
}

void handleDataOff(AsyncWebServerRequest *request) {
  dataConnDisable();
  request->redirect("/iot");
}

void handleDataPing(AsyncWebServerRequest *request) {
  String target = request->hasParam("target", true) ? request->getParam("target", true)->value() : "8.8.8.8";
  target.trim();
  dataConnPing(target);
  request->redirect("/iot");
}

void saveReportConfig(const String& times) {
  for (int i = 0; i < 16; i++) {
    char c = (i < times.length()) ? times[i] : 0;
    EEPROM.write(ADDR_REPORT_TIMES + i, c);
  }
  EEPROM.commit();
}

String loadReportConfig() {
  String times = "";
  for (int i = 0; i < 16; i++) {
    char c = EEPROM.read(ADDR_REPORT_TIMES + i);
    if (c == 0) break;
    times += c;
  }
  return times.length() > 0 ? times : "21:00";
}

void handleSaveReport(AsyncWebServerRequest *request) {
  if (request->hasParam("report_times", true)) {
    String rTimes = request->getParam("report_times", true)->value();
    rTimes.trim();
    gReportTimes = rTimes.length() ? rTimes : "21:00";
    saveReportConfig(gReportTimes);
    diagAdd("Riport időpontok mentve: " + gReportTimes);
  }
  request->redirect("/iot");
}

void handleTestReport(AsyncWebServerRequest *request) {
  String reportMsg = "🐝 **Kaptár Állapot Riport** \n\n";
  reportMsg += "| Azonosító | Család | Monitor |\n";
  reportMsg += "| A1B2 | Rendben | OK |\n";

  String nick = gNtfyNickname.length() ? gNtfyNickname : "szerver-" + macSuffix();
  bool ok = ntfy.send(reportMsg.c_str(), nick.c_str(), static_cast<NtfyPriority>(2));

  if (ok) diagAdd("Tesztriport elküldve.");
  else diagAdd("Tesztriport küldési hiba!");

  request->redirect("/iot");
}

void checkAndSendScheduledReport() {
  if (!gTime.synced || gTime.localTime.length() < 5) return;

  String currentTimeStr = "";
  if (gTime.localTime.length() >= 5) {
    int colonIdx = gTime.localTime.indexOf(':');
    if (colonIdx >= 2) {
      currentTimeStr = gTime.localTime.substring(colonIdx - 2, colonIdx + 3);
    }
  }

  if (currentTimeStr.length() != 5) return;

  int currentTotalMins = currentTimeStr.substring(0, 2).toInt() * 60 + currentTimeStr.substring(3, 5).toInt();
  if (currentTotalMins == gLastSentMinute) return;

  String timesCopy = gReportTimes;
  while (timesCopy.length() > 0) {
    int semiIdx = timesCopy.indexOf(';');
    String singleTime = (semiIdx >= 0) ? timesCopy.substring(0, semiIdx) : timesCopy;
    singleTime.trim();
    
    if (singleTime.length() == 5 && singleTime == currentTimeStr) {
      diagAdd("Időzített napi riport indítása (" + singleTime + ")");
      
      String reportMsg = "🐝 **Kaptár Állapot Riport (Ütemezett)** \n\n";
      reportMsg += "| Azonosító | Család | Monitor | Beavatkozás |\n";
      reportMsg += "| :--- | :--- | :--- | :--- |\n";
      reportMsg += "| A1B2 | Rendben | OK (100%) | 🟡 5 nap |\n";
      reportMsg += "| C3D4 | Ellenőrzés | OK (50%) | 🟠 2 nap |\n";
      reportMsg += "| E5F6 | Etetés | ⚠️ Akku (10%) | 🔴 Holnap |\n";
      reportMsg += "| G7H8 | Kezelés | ❌ Szenzor hiba | 🟣 Ma |\n";
      reportMsg += "| DEAD | 🔥 Hans | OFFLINE | 🔥 Hans |\n";

      String nick = gNtfyNickname;
      if (nick.length() == 0) nick = "szerver-" + macSuffix();

      int priorityVal = (reportMsg.indexOf("Hans") >= 0 || reportMsg.indexOf("🔥") >= 0) ? 5 : 2;

      bool ok = ntfy.send(reportMsg.c_str(), nick.c_str(), static_cast<NtfyPriority>(priorityVal));
      if (ok) {
        diagAdd("Ütemezett riport sikeresen elküldve (" + singleTime + ").");
      } else {
        diagAdd("Ütemezett riport küldési hiba!");
      }

      gLastSentMinute = currentTotalMins;
      break;
    }

    if (semiIdx < 0) break;
    timesCopy = timesCopy.substring(semiIdx + 1);
  }
}