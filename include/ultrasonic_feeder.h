#pragma once
#include <Arduino.h>
#include <EEPROM.h>
#include "config.h"

// Ultrahangos Tetőetető Szintmérő (JSN-SR04T / RCWL-1601 / HC-SR04)
#ifndef PIN_FEEDER_TRIG
#define PIN_FEEDER_TRIG 47
#endif
#ifndef PIN_FEEDER_ECHO
#define PIN_FEEDER_ECHO 48
#endif

// Alapértelmezett kalibrációs távolságok
#define FEEDER_DEFAULT_EMPTY_MM 200 // 200 mm = Üres tartály alja
#define FEEDER_DEFAULT_FULL_MM  30  // 30 mm = Tele szirupszint (maximális magasság)

void ultrasonicFeederInit();
uint16_t ultrasonicReadDistanceMm();
uint8_t ultrasonicGetLevelPercent();

// Kalibrációs műveletek az aktuális mért távolság alapján
bool ultrasonicCalibrateEmpty(); // Aktuális távolság mentése mint ÜRES (0%)
bool ultrasonicCalibrateFull();  // Aktuális távolság mentése mint TELE (100%)

void ultrasonicSetCalibration(uint16_t emptyMm, uint16_t fullMm);
uint16_t ultrasonicGetCalibEmptyMm();
uint16_t ultrasonicGetCalibFullMm();
void ultrasonicSaveCalibration();
void ultrasonicLoadCalibration();
