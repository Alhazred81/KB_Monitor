#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include "web_hives.h"
#include "web_common.h"
#include "web_theme.h"
#include "supabase_client.h"

extern bool checkPinGuard(AsyncWebServerRequest *request);

void handleHives(AsyncWebServerRequest *request) {
  if (!checkPinGuard(request)) return;

  String html = htmlHead("Kaptárak (Supabase)", "9"); // Javítva 9-re, hogy ne a GSM fület világítsa ki

  html += "<style>"
          ".hives-layout { display: flex; flex-direction: column; gap: 16px; max-width: 900px; margin: 0 auto; }"
          ".hive-table { width: 100%; border-collapse: collapse; font-size: 14px; }"
          ".hive-table th { text-align: left; padding: 12px; color: var(--txt2); border-bottom: 1px solid var(--border); font-size: 12px; text-transform: uppercase; letter-spacing: 1px; }"
          ".hive-table td { padding: 14px 12px; border-bottom: 1px solid rgba(255,255,255,0.05); }"
          ".badge { padding: 6px 12px; border-radius: 6px; font-size: 11px; font-weight: bold; text-align: center; display: inline-block; min-width: 90px; }"
          ".b-grn { background: rgba(34,197,94,0.15); color: #22c55e; border: 1px solid #22c55e; }"
          ".b-red { background: rgba(239,68,68,0.15); color: #ef4444; border: 1px solid #ef4444; }"
          "</style>";

  html += "<div class='hives-layout'>";
  html += "<div class='card full' style='margin:0; padding:20px;'>";
  html += "<h2 style='font-size:18px; margin-bottom:8px;'>☁️ Supabase Kaptár státuszok</h2>";
  html += "<p class='hint' style='margin-bottom:16px;'>A felhő adatbázisban rögzített utolsó telemetriai adatok.</p>";
  
  html += "<div style='overflow-x:auto;'>";
  html += "<table class='hive-table' id='hiveTable'>";
  html += "<tr><th>Kaptár / Eszköz</th><th>Utolsó frissítés</th><th>Hőmérséklet</th><th>Páratartalom</th><th>Súly</th></tr>";
  html += "<tr><td colspan='5' id='hiveLoading' style='text-align:center; padding: 20px; color: var(--txt2);'>Adatok betöltése a Supabase-ből...</td></tr>";
  html += "</table></div></div></div>";

  // Opcionális script, ha majd JSON API-n keresztül kérdezed le a táblát
  html += R"script(<script>
  // Ide jöhet majd a fetch hívás, ha készítünk egy /api/hives_supabase végpontot
  </script>)script";

  html += htmlFoot();
  request->send(200, "text/html", html);
}