#include "wifi_sta.h"
#include "connections.h" 
#include <Preferences.h> 

WifiStaState gSta;
ScannedNet gScanResults[MAX_SCAN_RESULTS];
int gScanCount = 0;
unsigned long gLastScan = 0;
unsigned long gLastStaCheck = 0;

extern String gApSSID;
extern String gApPass;
extern uint8_t gApChannel;

void wifiScan() {
  Serial.println(F("[WIFISTA] Halozatok keresese..."));
  int n = WiFi.scanNetworks(false, true);
  gScanCount = 0;
  for(int i=0; i<n && gScanCount<MAX_SCAN_RESULTS; i++){
    String ssid = WiFi.SSID(i);
    if(ssid.length()==0) continue; 
    
    bool dup = false;
    for(int j=0;j<gScanCount;j++){
      if(gScanResults[j].ssid == ssid){
        dup = true;
        if(WiFi.RSSI(i) > gScanResults[j].rssi) {
            gScanResults[j].rssi = WiFi.RSSI(i);
            gScanResults[j].channel = WiFi.channel(i); 
        }
        break;
      }
    }
    if(dup) continue;
    gScanResults[gScanCount].ssid   = ssid;
    gScanResults[gScanCount].rssi   = WiFi.RSSI(i);
    gScanResults[gScanCount].secure = (WiFi.encryptionType(i) != WIFI_AUTH_OPEN);
    gScanResults[gScanCount].channel = WiFi.channel(i); 
    gScanCount++;
  }
  WiFi.scanDelete();
  gLastScan = millis();
}

void wifiStaConnect(const String& ssid, const String& pass) {
  gSta.targetSSID = ssid;
  gSta.targetPass = pass;
  gSta.mode = NetMode::STA_CONNECTING;
  gSta.connectStarted = millis();
  gSta.lastError = "";

  WiFi.disconnect(false, true);
  delay(100);
  WiFi.mode(WIFI_AP_STA);
  WiFi.begin(ssid.c_str(), pass.length() ? pass.c_str() : NULL);
}

void wifiStaLoop() {
  if(gSta.mode != NetMode::STA_CONNECTING) return;
  wl_status_t st = WiFi.status();

  if(st == WL_CONNECTED){
    gSta.mode = NetMode::STA_CONNECTED;
    gSta.ip = WiFi.localIP().toString();
    Serial.println("\n[WIFISTA] >>> SIKERES CSATLAKOZAS! <<<");
    
    uint8_t currentChannel = WiFi.channel();
    Serial.printf("[WIFISTA] Aktiv kozos csatorna: %d\n", currentChannel);
    
    // KRITIKUS JAVÍTÁS: Mivel egy antenna van, az ESP-NOW-t és AP-t 
    // rá kell húzni a STA csatornájára, különben leszakad a Wi-Fi!
    gApChannel = currentChannel; 
    
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
      initServerEspNow(); 
    #endif
    
    ntpStart();
    saveStaCreds(gSta.targetSSID, gSta.targetPass);
    addSavedWifi(gSta.targetSSID, gSta.targetPass); // Hozzáadjuk a mentett listához

    WiFi.softAPdisconnect(true);
    WiFi.mode(WIFI_STA);
    return;
  }

  if(millis() - gSta.connectStarted > STA_CONNECT_TIMEOUT_MS){
    Serial.println(F("[WIFISTA] Csatlakozas idotullepes, vissza AP modba."));
    gSta.mode = NetMode::STA_FAILED;
    gSta.lastError = "Nem sikerult csatlakozni (" + gSta.targetSSID + ") - idotullepes vagy hibas jelszo.";
    gSta.lastAttempt = millis();

    WiFi.disconnect(true);
    WiFi.mode(WIFI_AP);
    
    WiFi.softAP(gApSSID.c_str(), gApPass.c_str(), gApChannel);
    
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
      initServerEspNow(); 
    #endif
  }
}

void wifiStaTryAutoConnect() {
  String ssid = loadStaSSID();
  if(ssid.length() == 0) return; 
  String pass = loadStaPass();
  wifiStaConnect(ssid, pass);
}

void wifiSuspendSta() {
  WiFi.disconnect(true); 
  gSta.mode = NetMode::AP;
  WiFi.mode(WIFI_AP);
  WiFi.softAP(gApSSID.c_str(), gApPass.c_str(), gApChannel);
  
  #if CURRENT_DEVICE_ROLE == ROLE_SERVER
    initServerEspNow(); 
  #endif
}

void wifiStaDisconnect() {
  clearStaCreds();
  wifiSuspendSta();
}

void wifiStaWatchdog() {
  if(gSta.mode != NetMode::STA_CONNECTED) return;
  if(millis() - gLastStaCheck < 10000) return; 
  gLastStaCheck = millis();

  wl_status_t st = WiFi.status();
  if(st != WL_CONNECTED){
    Serial.printf("\n[WIFISTA] ⚠️ KAPCSOLAT ELVESZETT! WiFi.status kod: %d\n", st);
    Serial.print("[WIFISTA] Részletes ok: ");
    switch(st) {
      case WL_NO_SSID_AVAIL: Serial.println("WL_NO_SSID_AVAIL (Router nem elerheto / Csatorna utkozes a radioban!)"); break;
      case WL_CONNECT_FAILED: Serial.println("WL_CONNECT_FAILED (Jelszo hiba / Elutasitva a router altal)"); break;
      case WL_CONNECTION_LOST: Serial.println("WL_CONNECTION_LOST (Fizikai szakadas / Gyenge jel)"); break;
      case WL_DISCONNECTED: Serial.println("WL_DISCONNECTED (Az ESP32 sajat maga bontotta a kapcsolatot)"); break;
      default: Serial.println("Ismeretlen hiba."); break;
    }
    
    gSta.mode = NetMode::AP;
    gSta.ip = "";
    gSta.lastError = "A WiFi kapcsolat megszakadt (" + gSta.targetSSID + "). Hiba: " + String(st);
    WiFi.mode(WIFI_AP);
    
    WiFi.softAP(gApSSID.c_str(), gApPass.c_str(), gApChannel);
    
    #if CURRENT_DEVICE_ROLE == ROLE_SERVER
      initServerEspNow(); 
    #endif
  }
}

// --- AP Kezelés ---
String loadApSSID() {
  Preferences prefs;
  prefs.begin("wifi_cfg", true);
  String ssid = prefs.getString("ap_ssid", "kaptarserver_AP");
  prefs.end();
  
  // Végleges védelem a "szellem" KB-teszt ellen
  if (ssid.startsWith("KB-teszt") || ssid == "") {
      ssid = "kaptarserver_AP";
      saveApSSID(ssid);
  }
  return ssid;
}

void saveApSSID(const String& ssid) {
  Preferences prefs;
  prefs.begin("wifi_cfg", false);
  prefs.putString("ap_ssid", ssid);
  prefs.end();
}

void saveApConfig(const String& ssid, const String& pass, uint8_t channel, bool apHide) {
  Preferences prefs;
  prefs.begin("wifi_cfg", false);
  prefs.putString("ap_ssid", ssid);
  prefs.putString("ap_pass", pass);
  prefs.putInt("ap_channel", channel);
  prefs.putBool("ap_hide", apHide);
  prefs.end();
}

bool loadApHide() {
  Preferences prefs;
  prefs.begin("wifi_cfg", true);
  bool hide = prefs.getBool("ap_hide", false);
  prefs.end();
  return hide;
}

// --- Mentett Hálózatok (Lista) Kezelése ---
void addSavedWifi(const String& ssid, const String& pass) {
    if(ssid.isEmpty()) return;
    Preferences prefs;
    prefs.begin("wifi_list", false);
    
    bool found = false;
    for(int i=0; i<5; i++){
        if(prefs.getString(("s"+String(i)).c_str(), "") == ssid){
            if(pass.length() > 0) prefs.putString(("p"+String(i)).c_str(), pass); 
            found = true;
            break;
        }
    }
    if(!found){
        for(int i=3; i>=0; i--){ // Csúsztatás, hogy max 5 maradjon
            prefs.putString(("s"+String(i+1)).c_str(), prefs.getString(("s"+String(i)).c_str(), ""));
            prefs.putString(("p"+String(i+1)).c_str(), prefs.getString(("p"+String(i)).c_str(), ""));
        }
        prefs.putString("s0", ssid);
        prefs.putString("p0", pass);
    }
    prefs.end();
}

String getSavedWifiJson() {
    Preferences prefs;
    prefs.begin("wifi_list", true);
    String json = "[";
    bool first = true;
    for(int i=0; i<5; i++){
        String s = prefs.getString(("s"+String(i)).c_str(), "");
        if(s.length() > 0){
            if(!first) json += ",";
            json += "\"" + s + "\"";
            first = false;
        }
    }
    json += "]";
    prefs.end();
    return json;
}

String getSavedWifiPass(const String& ssid) {
    Preferences prefs;
    prefs.begin("wifi_list", true);
    String pass = "";
    for(int i=0; i<5; i++){
        if(prefs.getString(("s"+String(i)).c_str(), "") == ssid){
            pass = prefs.getString(("p"+String(i)).c_str(), "");
            break;
        }
    }
    prefs.end();
    return pass;
}