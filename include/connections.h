#pragma once
#include <Arduino.h>
#include <esp_now.h>

extern unsigned long currentServerTimestamp;

// ─── RAM GYORSTÁR A WEBES MŰSZERFALNAK ───
#define MAX_RADIO_NODES 20

struct RadioNodeState {
  String macAddress;
  float tempInt;
  float humidity;
  float vbat;
  unsigned long lastSeen;
};

extern RadioNodeState gRadioNodes[MAX_RADIO_NODES];
extern int gRadioNodeCount;

// ─── KÖZÖS RÁDIÓS NAPLÓZÁS ───
String getRadioLog();
void clearRadioLog();

// ─── ESP-NOW (2.4 GHz) ───
void initServerEspNow();
void onEspNowReceive(const uint8_t *mac_addr, const uint8_t *incomingData, int len);
void sendEspNowAck(const uint8_t *mac_addr);

// ─── LORA (868 MHz SX1262) ───
bool initServerLoRa();
void handleLoRaReceive();
bool sendLoraAck(const String& targetMac);