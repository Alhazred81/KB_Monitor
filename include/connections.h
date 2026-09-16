#pragma once
#include <Arduino.h>
#include <esp_now.h>

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

// Ugyanaz a struktúra, mint amit a C3 kliensen használunk
enum WakeupReason { WAKE_TIMER = 0, WAKE_KNOCK = 1 };

typedef struct __attribute__((packed)) {
    uint8_t  monitor_id;
    uint8_t  reason;
    float    temp_c;
    float    humidity_pct;
    float    pressure_hpa;
    float    weight_kg;
    uint16_t feed_distance_mm;
    uint16_t voc_index;
    uint16_t nox_index;
    float    audio_zcr;
    uint8_t  audio_state;
    float    audio_bands[8];
    uint16_t battery_mv;
    uint32_t active_time_ms;
} HiveDataMsg;

// ESP-NOW inicializáló függvény a szerverhez
void initServerEspNow();