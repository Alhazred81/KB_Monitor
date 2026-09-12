#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER

#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include "web_gnss.h"
#include "web_common.h"
#include "gnss_mgr.h"
#include "modem_mgr.h"
#include "time_mgr.h"
#include "web_theme.h"

extern AsyncWebServer server;
extern GnssState gGnss;
extern ModemState gModem;
extern TimeState gTime;

void handleGnssStatus(AsyncWebServerRequest *request) {
  String json = "{";
  json += "\"enabled\":" + String(gGnss.enabled ? "true" : "false") + ",";
  json += "\"fix\":" + String(gGnss.fix ? "true" : "false") + ",";
  json += "\"lat\":" + String(gGnss.fix ? gGnss.lat : gGnss.assistLat, 6) + ",";
  json += "\"lon\":" + String(gGnss.fix ? gGnss.lon : gGnss.assistLon, 6) + ",";
  json += "\"alt\":" + String(gGnss.alt, 1) + ",";
  json += "\"speed\":" + String(gGnss.speed, 1) + ",";
  json += "\"hdop\":" + String(gGnss.hdop, 1) + ",";
  json += "\"satUsed\":" + String(gGnss.satUsed) + ",";
  json += "\"utc\":\"" + gGnss.dateStr + " " + gGnss.timeStr + "\"";
  json += "}";
  request->send(200, "application/json", json);
}

void handleGnss(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;
  String html = htmlHead("GPS", "6");

  if (!gModem.ready) {
    html += "<div class='msg err'>A modem nincs aktív, GNSS nem indítható.</div>";
  }

  double activeLat = gGnss.fix ? gGnss.lat : gGnss.assistLat;
  double activeLon = gGnss.fix ? gGnss.lon : gGnss.assistLon;
  char latS[16], lonS[16];
  dtostrf(activeLat, 0, 6, latS);
  dtostrf(activeLon, 0, 6, lonS);

  html += "<div class='card'><h2>GNSS Státusz & Pozíció</h2>";
  html += stateRow("Vevő státusz", gnssReceiverStatusText(), gGnss.fix ? "g" : (gGnss.enabled ? "y" : "r"));
  html += stateRow("Szélesség", String(latS) + "°", "");
  html += stateRow("Hosszúság", String(lonS) + "°", "");
  html += stateRow("Magasság", String(gGnss.alt, 1) + " m", "");
  html += stateRow("Használt műholdak", String(gGnss.satUsed), "");
  html += "</div>";

  html += "<div class='card'><h2>Kiinduló koordináta beállítása</h2>";
  html += "<form action='/gnssassist' method='POST'>";
  html += "<label>Latitude</label><input type='text' name='lat' value='" + String(gGnss.assistLat, 6) + "' inputmode='decimal'>";
  html += "<label>Longitude</label><input type='text' name='lon' value='" + String(gGnss.assistLon, 6) + "' inputmode='decimal'>";
  html += "<button class='sec'>Koordináta mentése</button></form>";
  html += "</div>";

  if (gGnss.enabled) {
    html += "<form action='/gnssctl' method='POST'><input type='hidden' name='action' value='stop'><button class='danger'>GNSS kikapcsolása</button></form>";
  } else {
    html += "<form action='/gnssctl' method='POST'><input type='hidden' name='action' value='start'><button style='background:var(--ok)'>GNSS bekapcsolása</button></form>";
  }

  html += htmlFoot();
  request->send(200, "text/html", html);
}

void handleGnssAssist(AsyncWebServerRequest *request) {
  if (!request->hasParam("lat", true) || !request->hasParam("lon", true)) {
    request->redirect("/gnss");
    return;
  }
  float lat = request->getParam("lat", true)->value().toFloat();
  float lon = request->getParam("lon", true)->value().toFloat();
  if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
    gnssSaveAssist(lat, lon, 1.0);
    diagAdd("GNSS kiinduló koordináta mentve: " + String(lat, 6) + ", " + String(lon, 6));
  }
  request->redirect("/gnss");
}

void handleGnssCtl(AsyncWebServerRequest *request) {
  if (request->hasParam("pos_days", true)) {
    uint8_t d = request->getParam("pos_days", true)->value().toInt();
    gnssSaveConfig(d);
  } else {
    String action = request->hasParam("action", true) ? request->getParam("action", true)->value() : "";
    if (action == "start") gnssStart();
    else if (action == "stop") gnssStop();
  }
  request->redirect("/gnss");
}

#endif // ROLE_SERVER