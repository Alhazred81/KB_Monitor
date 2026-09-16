#pragma once
#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_SERVER
#include <Arduino.h>
#include <esp_now.h>

#define MAX_ESP_NOW_HIVES 10

struct struct_data {
    float tempInt;
    float humInt;
};

struct HiveRecord {
    String macAddress;
    struct_data data;
    unsigned long lastSeen;
};

void initEspNowGateway(uint8_t channel);
#endif