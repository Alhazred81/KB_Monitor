//hive_msg.h

#pragma once
#include <stdint.h>

enum WakeupReason : uint8_t {
    WAKE_TIMER = 0,
    WAKE_ALARM_WEIGHT,
    WAKE_ALARM_TILT,
    WAKE_ALARM_AUDIO
};

typedef struct __attribute__((packed)) {
    uint8_t monitor_id;          
    WakeupReason reason;         
    
    // SHT40 / BMP280 adatok
    float temp_c;
    float humidity_pct;
    float pressure_hpa;
    
    // SGP41 adatok
    uint16_t voc_index;
    uint16_t nox_index;
    
    // Fizikai méretek (Mérleg, UH)
    float weight_kg;
    uint16_t feed_distance_mm;
    
    // Hangfeldolgozás eredményei
    float audio_zcr;
    uint8_t audio_state;
    float audio_bands[8]; // 32 bájt a sávoknak
    
    // Rendszerdiagnosztika
    uint16_t battery_mv;
    uint32_t active_time_ms;
} HiveDataMsg;