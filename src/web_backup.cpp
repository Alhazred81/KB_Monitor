#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include <Preferences.h>
#include <LittleFS.h>
#include "web_backup.h"
#include "web_common.h"
#include "web_theme.h"

extern AsyncWebServer server;

void handleEepromBackup(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;
    
    String html = htmlHead("EEPROM export", "5");
    html += "<div class='card wide'><h2>Beállítások Exportálása</h2>";
    html += "<p class='hint'>Másold ki az alábbi adatot a biztonsági mentéshez:</p>";
    html += "<textarea style='width:100%; height:100px; font-family:monospace;'>Mock_EEPROM_Backup_Data_String</textarea>";
    html += "<a href='/diag'><button class='sec' style='margin-top:10px'>Vissza</button></a>";
    html += "</div>";
    html += htmlFoot();
    request->send(200, "text/html", html);
}

void handleEepromRestore(AsyncWebServerRequest *request) {
    if (!checkPinGuard(request)) return;
    
    if (!request->hasParam("data", true)) {
        request->send(400, "text/plain", "Hiányzó adat a visszatöltéshez");
        return;
    }
    
    String data = request->getParam("data", true)->value();
    request->redirect("/diag");
}

#endif // ROLE_SERVER