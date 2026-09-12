#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include "web_iot.h"
#include "web_common.h"
#include "web_theme.h"
#include "NtfyClient.h"
#include "modem_mgr.h"

extern AsyncWebServer server;
extern NtfyClient ntfy;
extern ModemState gModem;
extern String modemBusyReason();

// Globális változók, amiket a Main.cpp keres
String gReportTimes = "";
bool gNtfySendDone = false;
String gNtfySendResult = "";

// A Main.cpp által hívott konfiguráció betöltő
String loadReportConfig() {
    // Alapértelmezett időzítés, később ide visszateheted az EEPROM olvasást
    gReportTimes = "19:00"; 
    return gReportTimes;
}

// A Main.cpp loop()-ja hívja
void checkAndSendScheduledReport() {
    // Ide jön majd az időzített riport küldésének logikája
}

void handleIot(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;
    String html = htmlHead("IoT", "3");

    // AJAX JS a teszt küldéshez, pollinggal (hasonlóan az SMS-hez)
    html += R"script(<script>
    function sendAjaxNtfy() {
        var btn = document.getElementById('ntfyBtn');
        var res = document.getElementById('ntfyResult');
        btn.disabled = true;
        res.style.display = 'block';
        res.innerHTML = '<span style="color:var(--txt2)">⏳ Küldés folyamatban...</span>';
        
        fetch('/ntfysend', {method: 'POST'})
        .then(function(r){ return r.json(); })
        .then(function(d){
            if(d.error) {
                res.innerHTML = '<span style="color:var(--err)">' + d.error + '</span>';
                btn.disabled = false;
            } else {
                ntfyPoll(); 
            }
        }).catch(function(e){
            res.innerHTML = '<span style="color:var(--err)">Hálózati hiba!</span>';
            btn.disabled = false;
        });
    }
    
    function ntfyPoll(){
        fetch('/ntfypoll')
        .then(function(r){ return r.json(); })
        .then(function(d){
            if(!d.done){
                setTimeout(ntfyPoll, 1000);
                return;
            }
            var res = document.getElementById('ntfyResult');
            var btn = document.getElementById('ntfyBtn');
            btn.disabled = false;
            if(d.ok){
                res.innerHTML = '<span style="color:var(--ok)">✓ ntfy üzenet sikeresen elküldve!</span>';
            } else {
                res.innerHTML = '<span style="color:var(--err)">✕ Hiba: ' + d.error + '</span>';
            }
        }).catch(function(){ setTimeout(ntfyPoll, 1500); });
    }
    </script>)script";

    html += "<div class='card wide'><h2>Adatkapcsolat</h2>";
    html += "<div style='display:flex;gap:8px;margin-bottom:15px'>";
    html += "<form action='/dataon' method='POST' style='flex:1'><button class='pri'>Adat bekapcsolása</button></form>";
    html += "<form action='/dataoff' method='POST' style='flex:1'><button class='sec'>Adat kikapcsolása</button></form>";
    html += "<form action='/dataping' method='POST' style='flex:1'><button class='sec'>Ping teszt</button></form>";
    html += "</div></div>";

    html += "<div class='card wide'><h2>ntfy.sh Értesítések</h2>";
    html += "<p class='hint'>Próbaüzenet küldése a beállított csatornára.</p>";
    html += "<button id='ntfyBtn' type='button' class='sec' onclick='sendAjaxNtfy()'>📱 Tesztüzenet Küldése</button>";
    html += "<div id='ntfyResult' style='margin-top:10px; font-weight:bold; display:none;'></div>";
    html += "</div>";
    
    html += htmlFoot();
    request->send(200, "text/html", html);
}

// Dummy adat handlerek, amiket a web_ui.cpp regisztrál
void handleDataOn(AsyncWebServerRequest *request) {
    diagAdd("Adatkapcsolat bekapcsolása kérve...");
    request->redirect("/iot");
}

void handleDataOff(AsyncWebServerRequest *request) {
    diagAdd("Adatkapcsolat kikapcsolása kérve...");
    request->redirect("/iot");
}

void handleDataPing(AsyncWebServerRequest *request) {
    diagAdd("Ping teszt indítása...");
    request->redirect("/iot");
}

void handleSaveNtfy(AsyncWebServerRequest *request) {
    request->redirect("/iot");
}

void handleSaveReport(AsyncWebServerRequest *request) {
    request->redirect("/iot");
}

// Az AJAX-os ntfy teszt küldő logikája
void handleNtfySend(AsyncWebServerRequest *request) {
    if(modemBusyReason().length() > 0) {
        request->send(200, "application/json", "{\"error\":\"" + modemBusyReason() + "\"}");
        return;
    }

    gNtfySendDone = false;
    gNtfySendResult = "";
    
    bool ok = ntfy.send("Sikeres szerver tesztüzenet!", "Teszt Riport", (NtfyPriority)3);
    
    gNtfySendDone = true;
    if (ok) {
        diagAdd("Teszt ntfy elküldve.");
        request->send(200, "application/json", "{\"error\":\"\",\"started\":true}");
    } else {
        gNtfySendResult = "ntfy küldési hiba";
        diagAdd("Hiba a teszt ntfy küldésekor.");
        request->send(200, "application/json", "{\"error\":\"Nem sikerült elküldeni az értesítést.\"}");
    }
}

// AJAX-os ntfy állapot lekérdező
void handleNtfyPoll(AsyncWebServerRequest *request) {
    String json = "{";
    json += "\"done\":" + String(gNtfySendDone ? "true" : "false") + ",";
    json += "\"ok\":" + String(gNtfySendDone && gNtfySendResult.length()==0 ? "true" : "false") + ",";
    json += "\"error\":\"" + gNtfySendResult + "\"";
    json += "}";
    request->send(200, "application/json", json);
}

// Tesztriport küldése (amit a web_ui.cpp keres)
void handleTestReport(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;
    
    bool sent = ntfy.send("Ez egy manuális tesztriport a rendszertől.", "Teszt Riport", (NtfyPriority)3);
    
    if (sent) {
        diagAdd("[NTFY] Tesztriport elküldve.");
        request->send(200, "text/plain", "Tesztriport sikeresen elküldve!");
    } else {
        diagAdd("[NTFY] Hiba a tesztriport küldésekor.");
        request->send(500, "text/plain", "Az ntfy küldés nem sikerült.");
    }
}

#endif // ROLE_SERVER