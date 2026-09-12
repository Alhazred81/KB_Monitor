#include <Arduino.h>
#include <ESPAsyncWebServer.h>

// --- Wi-Fi és Hálózat ---
__attribute__((weak)) void handleCfg(AsyncWebServerRequest *request) { request->send(200, "text/plain", "Konfig oldal (Csonk)"); }
__attribute__((weak)) void handleSaveWifi(AsyncWebServerRequest *request) { request->send(200, "text/plain", "Mentve"); }
__attribute__((weak)) void handleWifiScan(AsyncWebServerRequest *request) { request->send(200, "application/json", "[]"); }
__attribute__((weak)) void handleStaConnect(AsyncWebServerRequest *request) { request->send(200, "text/plain", "Csatlakozás..."); }
__attribute__((weak)) void handleStaDisconnect(AsyncWebServerRequest *request) { request->send(200, "text/plain", "Lecsatlakozva"); }

// --- Diagnosztika és Rendszer ---
__attribute__((weak)) void handleReinit(AsyncWebServerRequest *request) { request->redirect("/diag"); }
__attribute__((weak)) void handleEspRestart(AsyncWebServerRequest *request) { 
    request->send(200, "text/plain", "Újraindítás..."); 
    delay(1000); 
    ESP.restart(); 
}
__attribute__((weak)) void handleModemStatus(AsyncWebServerRequest *request) { request->send(200, "application/json", "{\"inProgress\":false}"); }

// --- Időjárás és Riasztások ---
__attribute__((weak)) void handleSaveWeatherCfg(AsyncWebServerRequest *request) { request->redirect("/cfg"); }
__attribute__((weak)) void handleTestWeatherAlert(AsyncWebServerRequest *request) { request->send(200, "text/plain", "Teszt riasztás elküldve"); }

// --- Expert Menü ---
__attribute__((weak)) void handleExpert(AsyncWebServerRequest *request) { request->send(200, "text/plain", "Expert Menü"); }
__attribute__((weak)) void handleAtStatus(AsyncWebServerRequest *request) { request->redirect("/diag"); }
__attribute__((weak)) void handleExpertPost(AsyncWebServerRequest *request) { request->redirect("/expert"); }
__attribute__((weak)) void handleExpertReset(AsyncWebServerRequest *request) { request->redirect("/expert"); }
__attribute__((weak)) void handleExpertFullReset(AsyncWebServerRequest *request) { request->redirect("/expert"); }

// --- Kaptár Adatok ---
__attribute__((weak)) void handleGetHivesJson(AsyncWebServerRequest *request) { request->send(200, "application/json", "[]"); }
__attribute__((weak)) void handleAddDummyHive(AsyncWebServerRequest *request) { request->send(200, "text/plain", "Dummy hozzáadva"); }