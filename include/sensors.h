#pragma once
#include <Arduino.h>
#include <Wire.h>
#include <EEPROM.h>
#include "config.h"

struct WindSpeedState {
  bool      enabled     = false;
  bool      lastReadOk  = false;
  float     speedMs     = 0;
  uint8_t   modbusAddr  = 2;
  unsigned long lastPoll = 0;
  unsigned long lastGoodRead = 0;
  String    lastError   = "";
  String    rawHex      = "";
};

struct WindDirState {
  bool      enabled     = false;
  bool      lastReadOk  = false;
  float     directionDeg= 0;
  uint8_t   modbusAddr  = 3;
  unsigned long lastPoll = 0;
  unsigned long lastGoodRead = 0;
  String    lastError   = "";
  String    rawHex      = "";
};

struct ShtSensorState {
  bool      enabled     = false;
  bool      lastReadOk  = false;
  float     tempC       = 0;
  float     humidityPct = 0;
  uint8_t   modbusAddr  = 4;
  unsigned long lastPoll = 0;
  unsigned long lastGoodRead = 0;
  String    lastError   = "";
  String    rawHex      = "";
};

struct RainSensorState {
  bool      enabled     = false;
  int       rawValue    = 0;
  int       percentWet  = 0;
  bool      isRaining   = false;
  bool      isModbus    = false;
  uint8_t   modbusAddr  = 5;
  unsigned long lastPoll = 0;
  String    lastError   = "";
  String    rawHex      = "";
};

struct Mpu6050State {
  bool      enabled     = false;
  bool      lastReadOk  = false;
  float     accelX = 0, accelY = 0, accelZ = 0;
  float     gyroX = 0, gyroY = 0, gyroZ = 0;
  float     tempC = 0;
  unsigned long lastPoll = 0;
  unsigned long lastGoodRead = 0;
  String    lastError = "";
};

struct Aht20State {
  bool      enabled = false;
  bool      lastReadOk = false;
  float     tempC = 0;
  float     humidityPct = 0;
  unsigned long lastPoll = 0;
  unsigned long lastGoodRead = 0;
  String    lastError = "";
};

struct Bmp280State {
  bool      enabled = false;
  bool      lastReadOk = false;
  float     tempC = 0;
  float     pressureHpa = 0;
  unsigned long lastPoll = 0;
  unsigned long lastGoodRead = 0;
  String    lastError = "";
};

struct Ltr390State {
    bool enabled;
    bool lastReadOk;
    unsigned long lastPoll;
    unsigned long lastGoodRead;
    String lastError;
    uint32_t uvRaw;
    float uvIndex;
    float lux;
};

extern WindSpeedState   gWindSpeed;
extern WindDirState     gWindDir;
extern ShtSensorState   gSht;
extern RainSensorState  gRain;
extern Mpu6050State     gMpu;
extern Aht20State       gAht20;
extern Bmp280State      gBmp280;
extern Ltr390State      gLtr;

extern uint8_t gSensEnableMask;
extern uint32_t gSensRs485Baud;
extern unsigned long gLastSensorPoll;
extern uint8_t gSensorPollStep;
extern HardwareSerial rs485Serial;
extern bool gRs485Initialized;
extern bool gI2c1Initialized;
extern bool gI2c2Initialized;
extern String gLastSensTestResult;
extern bool   gLastSensTestOk;
extern String gLastSensTestRaw;

bool sensEnabled(uint8_t bit);
void sensSetEnabled(uint8_t bit, bool en);
void saveSensorConfig();
void loadSensorConfig();

uint16_t modbusCrc16(const uint8_t* data, size_t len);
void rs485Init();
void rs485SetDirection(bool transmit);
bool modbusReadHoldingRegisters(uint8_t slaveAddr, uint16_t startReg, uint8_t count,
                                   uint16_t* outValues, String& rawHexOut, String& errOut);

void windSpeedPoll();
void windDirPoll();
void shtSensorPoll();
void rainSensorPoll();

bool mpu6050WriteReg(uint8_t reg, uint8_t val);
void mpu6050Init();
void mpu6050Poll();

void i2c2Init();
void aht20Poll();
void bmp280Poll();
void ltr390Poll();

void sensorsApplyEnabled();
void sensTestRun(const String& which);
void sensorsLoop();
String performI2cScan();