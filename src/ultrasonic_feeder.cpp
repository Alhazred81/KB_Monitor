#include "ultrasonic_feeder.h"

static uint16_t s_emptyMm = FEEDER_DEFAULT_EMPTY_MM;
static uint16_t s_fullMm = FEEDER_DEFAULT_FULL_MM;

#define ADDR_FEEDER_CALIB_FLAG 310
#define ADDR_FEEDER_EMPTY_MM   311
#define ADDR_FEEDER_FULL_MM    313

void ultrasonicFeederInit() {
    pinMode(PIN_FEEDER_TRIG, OUTPUT);
    pinMode(PIN_FEEDER_ECHO, INPUT);
    digitalWrite(PIN_FEEDER_TRIG, LOW);
    ultrasonicLoadCalibration();
}

uint16_t ultrasonicReadDistanceMm() {
    // 3 mérés medián/átlag szűrése a folyadékfelszín hullámzásának kiszűrésére
    long durations[3];
    int validCount = 0;

    for (int i = 0; i < 3; i++) {
        digitalWrite(PIN_FEEDER_TRIG, LOW);
        delayMicroseconds(2);
        digitalWrite(PIN_FEEDER_TRIG, HIGH);
        delayMicroseconds(10);
        digitalWrite(PIN_FEEDER_TRIG, LOW);

        // Max 30ms timeout (~5 méter hatótáv)
        long duration = pulseIn(PIN_FEEDER_ECHO, HIGH, 30000);
        if (duration > 100) { // legalább ~1.7 cm
            durations[validCount++] = duration;
        }
        delay(15);
    }

    if (validCount == 0) {
        return s_emptyMm; // Timeout esetén az üres távolságot feltételezzük
    }

    // Átlagolás a valid mérésekből
    long sum = 0;
    for (int i = 0; i < validCount; i++) {
        sum += durations[i];
    }
    long avgDuration = sum / validCount;

    // Hangsebesség: ~343 m/s = 0.343 mm/us, oda-vissza út osztva 2-vel
    uint16_t distanceMm = (uint16_t)((avgDuration * 0.343) / 2.0);
    return distanceMm;
}

uint8_t ultrasonicGetLevelPercent() {
    uint16_t currentMm = ultrasonicReadDistanceMm();

    if (s_emptyMm <= s_fullMm) {
        return 0;
    }

    if (currentMm >= s_emptyMm) {
        return 0; // Folyadék az alján van vagy alatta
    }
    if (currentMm <= s_fullMm) {
        return 100; // Tartály tele
    }

    // Százalékos számítás: kisebb távolság = magasabb folyadékszint
    float percent = ((float)(s_emptyMm - currentMm) / (float)(s_emptyMm - s_fullMm)) * 100.0f;
    if (percent < 0.0f) percent = 0.0f;
    if (percent > 100.0f) percent = 100.0f;

    return (uint8_t)(percent + 0.5f);
}

bool ultrasonicCalibrateEmpty() {
    uint16_t measured = ultrasonicReadDistanceMm();
    if (measured < 20 || measured > 1000) {
        return false; // Érvénytelen mérés
    }
    s_emptyMm = measured;
    ultrasonicSaveCalibration();
    return true;
}

bool ultrasonicCalibrateFull() {
    uint16_t measured = ultrasonicReadDistanceMm();
    if (measured < 15 || measured > 1000) {
        return false; // Érvénytelen mérés
    }
    s_fullMm = measured;
    ultrasonicSaveCalibration();
    return true;
}

void ultrasonicSetCalibration(uint16_t emptyMm, uint16_t fullMm) {
    s_emptyMm = emptyMm;
    s_fullMm = fullMm;
    ultrasonicSaveCalibration();
}

uint16_t ultrasonicGetCalibEmptyMm() {
    return s_emptyMm;
}

uint16_t ultrasonicGetCalibFullMm() {
    return s_fullMm;
}

void ultrasonicSaveCalibration() {
    EEPROM.write(ADDR_FEEDER_CALIB_FLAG, 0xA5);
    EEPROM.write(ADDR_FEEDER_EMPTY_MM, (s_emptyMm >> 8) & 0xFF);
    EEPROM.write(ADDR_FEEDER_EMPTY_MM + 1, s_emptyMm & 0xFF);
    EEPROM.write(ADDR_FEEDER_FULL_MM, (s_fullMm >> 8) & 0xFF);
    EEPROM.write(ADDR_FEEDER_FULL_MM + 1, s_fullMm & 0xFF);
    EEPROM.commit();
}

void ultrasonicLoadCalibration() {
    if (EEPROM.read(ADDR_FEEDER_CALIB_FLAG) == 0xA5) {
        s_emptyMm = (EEPROM.read(ADDR_FEEDER_EMPTY_MM) << 8) | EEPROM.read(ADDR_FEEDER_EMPTY_MM + 1);
        s_fullMm = (EEPROM.read(ADDR_FEEDER_FULL_MM) << 8) | EEPROM.read(ADDR_FEEDER_FULL_MM + 1);
        if (s_emptyMm == 0 || s_emptyMm == 0xFFFF) s_emptyMm = FEEDER_DEFAULT_EMPTY_MM;
        if (s_fullMm == 0 || s_fullMm == 0xFFFF) s_fullMm = FEEDER_DEFAULT_FULL_MM;
    } else {
        s_emptyMm = FEEDER_DEFAULT_EMPTY_MM;
        s_fullMm = FEEDER_DEFAULT_FULL_MM;
    }
}
