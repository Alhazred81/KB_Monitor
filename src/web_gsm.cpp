#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include "web_gsm.h"
#include "modem_mgr.h"
#include "web_common.h"
#include "web_theme.h"

extern ModemState gModem;
extern unsigned long gLastSms;
extern bool gSmsSendRequested;
extern String gSmsPendingNum;
extern String gSmsPendingText;
extern bool gSmsSendInProgress;
extern bool gSmsSendDone;
extern String gSmsSendResult;

bool sendModemBusyPage(AsyncWebServerRequest *request, const String& title, const String& active, const String& backUrl);

void handleGsm(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String html = htmlHead("GSM", "2");

  html += "<div class='card wide'><h2>SMS Küldés</h2>";
  html += "<form action='/dosms' method='POST'>";
  html += phoneInputBlock("smsBtn", "num");
  html += "<label>Üzenet</label><textarea name='smstext' maxlength='160'></textarea>";
  html += "<button id='smsBtn' disabled>SMS Küldés</button></form></div>";

  html += "<div class='card'><h2>Hívásteszt</h2>";
  html += "<form action='/docall' method='POST'>";
  html += phoneInputBlock("callBtn", "cnum");
  html += "<button id='callBtn' disabled>Hívás indítása</button></form></div>";

  html += "<div class='card'><h2>SMS Központ (SMSC)</h2>";
  html += "<form action='/setsmsc' method='POST'>";
  html += "<label>Központ száma (pl. +36309888000)</label>";
  html += "<input type='text' name='smsc' value='" + gModem.smscNumber + "'>";
  html += "<button class='sec'>Mentés</button></form></div>";

  html += "<div class='card wide'><h2>Hálózatválasztás (Automata / Kézi)</h2>";
  html += "<p class='hint'>Alapértelmezésben automata, de fix telepítésnél rögzítheted a saját szolgáltatód, hogy ne keresgéljen feleslegesen.</p>";
  
  html += stateRow("Jelenlegi operátor", gModem.operatorName.length() ? gModem.operatorName : "Ismeretlen", "");
  html += stateRow("Hálózati típus", gModem.netType.length() ? gModem.netType : "Ismeretlen", "");

  html += "<div style='display:flex;gap:8px;margin-top:12px;flex-wrap:wrap'>";
  html += "<form action='/netauto' method='POST' style='flex:1;min-width:140px'><button class='sec'>🔄 Váltás Automatikusra</button></form>";
  html += "<form action='/netscan' method='POST' style='flex:1;min-width:140px'><button class='sec'>📡 Hálózatok keresése</button></form>";
  html += "</div>";

  html += "<form action='/netmanual' method='POST' style='margin-top:14px;border-top:1px solid var(--border);padding-top:12px'>";
  html += "<label>Kézi hálózat rögzítése (MCC/MNC kód, pl. Telekom: 21630)</label>";
  html += "<div style='display:flex;gap:8px'>";
  html += "<input type='text' name='netcode' placeholder='pl. 21630' style='flex:1;margin:0'>";
  html += "<button style='width:auto;padding:0 16px'>Rögzítés</button>";
  html += "</div></form>";

  html += "</div>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleDoSms(AsyncWebServerRequest *request) {
  if(sendModemBusyPage(request, "SMS", "2", "/gsm")) return;
  if(!request->hasParam("num", true) || !request->hasParam("smstext", true)){
    request->redirect("/gsm"); return;
  }

  unsigned long left = 0;
  if(gLastSms > 0 && millis()-gLastSms < SMS_COOLDOWN_MS)
    left = (SMS_COOLDOWN_MS-(millis()-gLastSms))/1000;
  if(left > 0){
    request->redirect("/gsm"); return;
  }

  String num = request->getParam("num", true)->value(); num.trim();
  String smstext = request->getParam("smstext", true)->value(); smstext.trim();

  String clean = "";
  for(int i=0; i<(int)smstext.length() && i<SMS_MAX_LEN; i++){
    char c = smstext[i];
    if((uint8_t)c >= 0x80) continue;
    clean += c;
  }

  String html = htmlHead("SMS", "2");

  if(!num.startsWith("+36") || num.length() != 12){
    html += "<div class='msg err'>Érvénytelen telefonszám! A formátum: +36xxxxxxxxx.</div>";
    html += "<a href='/gsm'><button class='sec'>Vissza</button></a>";
    html += htmlFoot();
    request->send(200, "text/html", html);
    return;
  }
  if(clean.length() == 0){
    html += "<div class='msg err'>Az üzenet üres maradt az ékezet-szűrés után.</div>";
    html += "<a href='/gsm'><button class='sec'>Vissza</button></a>";
    html += htmlFoot();
    request->send(200, "text/html", html);
    return;
  }

  gSmsPendingNum  = num;
  gSmsPendingText = clean;
  gSmsSendDone    = false;
  gSmsSendResult  = "";
  gSmsSendRequested = true;

  html += "<div class='card full'>"
    "<div style='text-align:center;padding:8px'>"
    "<div id='smsPhase' style='font-size:13px;color:var(--txt2)'>SMS küldése folyamatban...</div>"
    "<div id='smsSpin' style='font-size:28px;margin:10px 0'>⏳</div>"
    "<div id='smsResult' style='display:none'></div>"
    "<a href='/gsm'><button id='smsWaitBtn' class='sec' disabled style='margin-top:12px'>Várakozás...</button></a>"
    "</div></div>"
    "<script>"
    "function smsPoll(){"
      "fetch('/smsstatus').then(function(r){return r.json();}).then(function(d){"
        "if(!d.done){"
          "setTimeout(smsPoll, 1000);"
          "return;"
        "}"
        "document.getElementById('smsSpin').style.display='none';"
        "document.getElementById('smsPhase').innerText = d.ok ? 'Kész!' : 'Sikertelen.';"
        "var res = document.getElementById('smsResult');"
        "res.style.display='block';"
        "var btn = document.getElementById('smsWaitBtn');"
        "btn.disabled = false;"
        "btn.innerText = 'Vissza az SMS oldalra';"
        "btn.style.background = d.ok ? 'var(--ok)' : '';"
        "if(d.ok){"
          "res.innerHTML = \"<div class='msg ok'>✓ SMS elküldve!</div>\";"
        "} else {"
          "res.innerHTML = \"<div class='msg err'>SMS küldés sikertelen: \" + d.error + \"</div>\";"
        "}"
      "}).catch(function(){ setTimeout(smsPoll, 1500); });"
    "}"
    "setTimeout(smsPoll, 500);"
    "</script>";

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleSmsStatus(AsyncWebServerRequest *request) {
  String json = "{";
  json += "\"done\":" + String(gSmsSendDone ? "true" : "false") + ",";
  json += "\"ok\":" + String(gSmsSendDone && gSmsSendResult.length()==0 ? "true" : "false") + ",";
  json += "\"error\":\"" + jsEscape(gSmsSendResult) + "\"";
  json += "}";
  request->send(200, "application/json", json);
}

void handleDoCall(AsyncWebServerRequest *request) {
  if(sendModemBusyPage(request, "Hívás", "2", "/gsm")) return;
  if(!request->hasParam("num", true)){ request->redirect("/gsm"); return; }
  String num = request->getParam("num", true)->value(); num.trim();
  String html = htmlHead("Hívás", "2");

  if(!num.startsWith("+36") || num.length() != 12){
    html += "<div class='msg err'>Érvénytelen szám! A formátum: +36xxxxxxxxx.</div>";
  } else {
    String err = startCall(num);
    if(err.length() == 0){
      diagAdd("Hívás indítva -> " + num);
      html += "<div class='msg ok'>📞 Hívás indítva: " + num + "</div>"
              "<div class='hint'>A hívás automatikusan bontódik.</div>"
              "<form action='/hangup' method='POST'>"
              "<button class='danger' style='margin-top:14px'>🚫 Azonnali bontás</button></form>";
    } else {
      diagAdd("Hívás HIBA -> " + num + ": " + err);
      html += "<div class='msg err'>Hívás indítás sikertelen: " + err + "</div>";
    }
  }
  html += "<a href='/gsm'><button class='sec'>Vissza</button></a>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleHangup(AsyncWebServerRequest *request) {
  hangUp();
  diagAdd("Hívás bontva (manuális)");
  request->redirect("/gsm");
}

void handleSetSmsc(AsyncWebServerRequest *request) {
  if(sendModemBusyPage(request, "SMSC beállítás", "2", "/gsm")) return;
  if(!request->hasParam("smsc", true)){ request->redirect("/gsm"); return; }
  String smsc = request->getParam("smsc", true)->value(); smsc.trim();

  String html = htmlHead("SMSC beállítás", "2");

  if(smsc.length() == 0) {
    html += "<div class='msg err'>Az SMSC szám nem lehet üres.</div>";
  } else {
    String err = setSmsc(smsc);
    if(err.length() == 0) {
      diagAdd("SMSC beállítva: " + smsc);
      html += "<div class='msg ok'>SMSC szám beállítva: " + htmlEscape(smsc) + "</div>";
    } else {
      diagAdd("SMSC beállítás HIBA: " + err);
      html += "<div class='msg err'>" + err + "</div>";
    }
  }
  html += "<a href='/gsm'><button class='sec'>Vissza</button></a>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleNetAuto(AsyncWebServerRequest *request) {
  if(sendModemBusyPage(request, "Hálózatváltás", "2", "/gsm")) return;
  String err = setAutoNetwork();
  if(err.length() == 0) {
    diagAdd("Hálózat visszaállítva automatikus módra.");
  } else {
    diagAdd("Hiba automatikus hálózatváltáskor: " + err);
  }
  request->redirect("/gsm");
}

void handleNetScan(AsyncWebServerRequest *request) {
  if(sendModemBusyPage(request, "Hálózatkeresés", "2", "/gsm")) return;
  diagAdd("Hálózatok keresése indítva (AT+COPS=)...");
  String rawRes = scanAvailableNetworks();
  diagAdd("Hálózat keresés eredménye: " + rawRes);
  
  String html = htmlHead("Hálózatválasztás", "2");
  html += "<h1>Elérhető mobilhálózatok</h1>";
  html += "<div class='card wide'>";
  html += "<p class='hint'>Válaszd ki az alábbi listából a kívánt hálózatot a rögzítéshez:</p>";

  html += "<form action='/netmanual' method='POST'>";
  html += "<label>Talált hálózatok</label>";
  html += "<select name='netcode' style='margin-bottom:12px'>";

  int pos = 0;
  bool foundAny = false;

  while(true) {
    int start = rawRes.indexOf('(', pos);
    if(start < 0) break;
    int end = rawRes.indexOf(')', start);
    if(end < 0) break;
    
    String entry = rawRes.substring(start + 1, end);
    pos = end + 1;

    String parts[10];
    int partCount = 0;
    int pIdx = 0;
    while(partCount < 10) {
      int q1 = entry.indexOf('"', pIdx);
      if(q1 < 0) break;
      int q2 = entry.indexOf('"', q1 + 1);
      if(q2 < 0) break;
      parts[partCount++] = entry.substring(q1 + 1, q2);
      pIdx = q2 + 1;
    }

    if(partCount >= 2) {
      String netName = parts[0];
      String netCode = "";
      for(int i = 0; i < partCount; i++) {
        if(parts[i].length() == 5 && isDigit(parts[i][0])) {
          netCode = parts[i];
          break;
        }
      }
      if(netCode.length() > 0) {
        foundAny = true;
        html += "<option value='" + netCode + "'>" + htmlEscape(netName) + " (" + netCode + ")</option>";
      }
    }
  }

  if(!foundAny) html += "<option value=''>Nem található értelmezhető hálózat</option>";

  html += "</select>";
  html += "<button style='margin-top:6px' " + String(foundAny ? "" : "disabled") + ">Kiválasztott hálózat rögzítése</button>";
  html += "</form>";

  html += "<details style='margin-top:20px'><summary class='hint' style='cursor:pointer'>Nyers modem válasz</summary>";
  html += "<div class='diag' style='margin-top:6px'>" + htmlEscape(rawRes) + "</div></details>";

  html += "<a href='/gsm'><button class='sec' style='margin-top:14px'>Vissza a GSM oldalra</button></a></div>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleNetManual(AsyncWebServerRequest *request) {
  if(sendModemBusyPage(request, "Kézi Hálózat", "2", "/gsm")) return;
  if(!request->hasParam("netcode", true)) {
    request->redirect("/gsm");
    return;
  }
  String code = request->getParam("netcode", true)->value();
  code.trim();
  
  String err = setManualNetwork(code, 7); 
  String html = htmlHead("Hálózat rögzítés", "2");
  html += "<h1>Kézi hálózat rögzítése</h1>";
  
  if(err.length() == 0) {
    diagAdd("Sikeresen rögzítve a kézi hálózat: " + code);
    html += "<div class='msg ok'>A hálózat sikeresen rögzítve: " + htmlEscape(code) + "</div>";
  } else {
    diagAdd("Hiba a hálózat rögzítésekor: " + err);
    html += "<div class='msg err'>" + htmlEscape(err) + "</div>";
  }
  
  html += "<a href='/gsm'><button class='sec'>Vissza a GSM oldalra</button></a>";
  html += htmlFoot();
  request->send(200, "text/html", html);
}

String modemBusyReason() {
  if(gModemInitRequested || gModem.initInProgress) return "Modem inicializálás folyamatban, várj amíg befejeződik.";
  if(gSmsSendRequested || gSmsSendInProgress) return "SMS küldés folyamatban, közben a modem soros portja foglalt.";
  if(gData.inProgress) return "Adatkapcsolat váltás folyamatban, várj pár másodpercet.";
  if(gData.pingInProgress) return "Ping teszt folyamatban, várj pár másodpercet.";
  if(gModem.callActive) return "Hívás folyamatban, közben a modem soros portját nem piszkáljuk.";
  return "";
}

bool sendModemBusyPage(AsyncWebServerRequest *request, const String& title, const String& active, const String& backUrl) {
  String reason = modemBusyReason();
  if(reason.length() == 0) return false;
  String html = htmlHead(title, active);
  html += "<h1>Modem foglalt</h1>";
  html += "<div class='msg warn'>" + htmlEscape(reason) + "</div>";
  html += "<a href='" + backUrl + "'><button class='sec'>Vissza</button></a>";
  html += htmlFoot();
  request->send(200, "text/html", html);
  return true;
}

#endif // ROLE_SERVER