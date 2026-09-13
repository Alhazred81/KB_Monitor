#pragma once

#define ROLE_SERVER 1
#define ROLE_MONITOR 2
#define ROLE_GATEWAY 3

#ifndef CURRENT_DEVICE_ROLE
#define CURRENT_DEVICE_ROLE ROLE_SERVER
#endif

// Periféria engedélyezések szerepkör alapján
#define HAS_SHT40      (CURRENT_DEVICE_ROLE == ROLE_MONITOR)
#define HAS_SGP41      (CURRENT_DEVICE_ROLE == ROLE_MONITOR)
#define HAS_HX711      (CURRENT_DEVICE_ROLE == ROLE_MONITOR)
#define HAS_ULTRASONIC (CURRENT_DEVICE_ROLE == ROLE_MONITOR)
#define HAS_MICROPHONE (CURRENT_DEVICE_ROLE == ROLE_MONITOR)
#define ENABLE_BRIDGE  (CURRENT_DEVICE_ROLE == ROLE_GATEWAY)

// ─── LED / Panelverzió opciók ───────────────────────────────
#define LED_MODE_V10        0
#define LED_MODE_V11        1
#define LED_MODE_CUSTOM     2
#define LED_MODE_AT_NETLIGHT 3

#define LED_PIN_V10        12
#define LED_PIN_V11        13
#define DEFAULT_LED_MODE   LED_MODE_V10
#define DEFAULT_CUSTOM_PIN 2

// ─── WiFi AP ────────────────────────────────────────────────
#define AP_PREFIX          "Server-"
#define DEFAULT_AP_PASS  "12345678"
#define DEFAULT_CHANNEL  11

// ─── SMS ────────────────────────────────────────────────    
#define SMS_COOLDOWN_MS  30000UL
#define SMS_MAX_LEN      160
#define SMS_INBOX_HARD_MAX 50
#define SMS_INBOX_DEFAULT_LIMIT 10

// ─── GNSS ───────────────────────────────────────────────────
#define GNSS_POLL_INTERVAL_MS  5000UL
#define GNSS_DEFAULT_ASSIST_LAT 47.514600f
#define GNSS_DEFAULT_ASSIST_LON 19.043500f

// ─── STA (kliens) WiFi mód ────────────────────────────────────
#define STA_CONNECT_TIMEOUT_MS   15000UL
#define STA_RETRY_INTERVAL_MS    30000UL

// ─── ESP-NOW Korlátok ───────────────────────────────────────
#define MAX_ESP_NOW_HIVES 10

// ─── EEPROM layout (512 byte) ───────────────────────────────
#define EEPROM_SIZE          512
#define ADDR_AP_PASS         0   // 32 byte
#define ADDR_CHANNEL        32   //  1 byte
#define ADDR_PIN_FLAG       33   //  1 byte
#define ADDR_PIN            34   //  8 byte
#define ADDR_CCID           42   // 20 byte
#define ADDR_CCID_FLAG      62   //  1 byte
#define ADDR_LED_MODE       63   //  1 byte
#define ADDR_LED_CUSTOM     64   //  1 byte
#define ADDR_STA_FLAG       65   //  1 byte
#define ADDR_STA_SSID       66   // 96 byte
#define ADDR_STA_PASS      162   // 64 byte
#define ADDR_GNSS_ASSIST_FLAG 226 //  1 byte
#define ADDR_GNSS_ASSIST_LAT  227 //  4 byte float
#define ADDR_GNSS_ASSIST_LON  231 //  4 byte float
#define ADDR_SMS_INBOX_LIMIT  235 //  1 byte
#define ADDR_NTFY_STARTUP 236 // 1 byte
#define ADDR_REPORT_TIMES 237   // 16 byte
#define ADDR_POS_DAYS 253 // 1 byte
#define ADDR_AP_HIDE  254 // 1 byte (AP rejtett SSID opció)

// ─── Szenzor beallitasok EEPROM cimei (256-tol) ─────────────
#define ADDR_SENS_FLAG           256
#define ADDR_SENS_ENABLE_MASK    257
#define ADDR_SENS_RS485_BAUD     258
#define ADDR_SENS_ADDR_WINDSPEED 262
#define ADDR_SENS_ADDR_WINDDIR   263
#define ADDR_SENS_ADDR_SHT       264
#define ADDR_SENS_ADDR_RAIN      265
#define ADDR_SENS_RAIN_MODE      266
#define ADDR_AP_SSID             270 // 32 byte

#define MAGIC_BYTE          0xA5
#define DNS_PORT_NUM        53

// ─── Pinout & Perifériák Szerepkör Alapján ──────────────────
#if CURRENT_DEVICE_ROLE == ROLE_SERVER
    // --- SZERVER (TTGO T-SIM7000G) PINOUT ---
    #define MODEM_TX      27
    #define MODEM_RX      26
    #define MODEM_PWRKEY   4
    #define MODEM_RST      5
    #define MODEM_DTR     25
    #define MODEM_RI      33
    #define MODEM_SLP     36
    #define MODEM_KEY     37

    // LoRa SX1262 (Szerver)
    #define LORA_NSS      17
    #define LORA_SCK       6
    #define LORA_MISO      4
    #define LORA_MOSI      5
    #define LORA_DIO1      7
    #define LORA_RST      16
    #define LORA_BUSY     15
    #define LORA_RXEN     RADIOLIB_NC
    #define LORA_TXEN     RADIOLIB_NC

    #define PIN_BAT_ADC    9
    #define PIN_HALL       1
    #define WAKE_PIN      39

    // USB
    #define PIN_USB_D_MINUS 19
    #define PIN_USB_D_PLUS  20

    // MPU6050 & Külső I2C (Szabványos ESP32 I2C lábak)
    #define SENS_I2C1_SDA_DEFAULT 21
    #define SENS_I2C1_SCL_DEFAULT 22
    #define SENS_I2C2_SDA_DEFAULT 21
    #define SENS_I2C2_SCL_DEFAULT 22

    // RS485
    #define RS485_DI       38
    #define RS485_DE       39
    #define RS485_RO       40

#elif CURRENT_DEVICE_ROLE == ROLE_GATEWAY
    // --- GATEWAY PINOUT ---
    #define PIN_HALL       1
    #define PIN_BAT_ADC    3
    #define WAKE_PIN       4

    // USB
    #define PIN_USB_D_MINUS 19
    #define PIN_USB_D_PLUS  20

    // LoRa SX1262 (Gateway / Monitor alap)
    #define LORA_NSS      41
    #define LORA_SCK       0   // TX0 pin
    #define LORA_MISO      2
    #define LORA_MOSI      3   // RX pin
    #define LORA_DIO1     40
    #define LORA_RST      42
    #define LORA_BUSY     39
    #define LORA_RXEN     RADIOLIB_NC
    #define LORA_TXEN     RADIOLIB_NC

#else
    // --- KAPTÁRMONITOR PINOUT ---
    #define PIN_HALL       1
    #define PIN_BAT_ADC    3
    #define WAKE_PIN      21   // Ajtó / ébresztő pin

    // MPU6050
    #define SENS_I2C1_SCL_DEFAULT 4
    #define SENS_I2C1_SDA_DEFAULT 5
    #define PIN_MPU_INT    6

    // 32768Hz kristály
    #define PIN_XTAL_32K_1 15
    #define PIN_XTAL_32K_2 16

    // Kimenő I2C
    #define SENS_I2C2_SCL_DEFAULT 17
    #define SENS_I2C2_SDA_DEFAULT 18

    // Szenzor táp engedélyezés
    #define PIN_SENSOR_EN  8

    // USB
    #define PIN_USB_D_MINUS 19
    #define PIN_USB_D_PLUS  20

    // HX711 Mérleg
    #define PIN_HX711_SCK  9
    #define PIN_HX711_DO   10

    // INMP Mikrofon
    #define PIN_INMP_SCK   12
    #define PIN_INMP_WS    13
    #define PIN_INMP_SD    14

    // LoRa SX1262
    #define LORA_NSS      41
    #define LORA_SCK       0   // TX0 pin
    #define LORA_MISO      2
    #define LORA_MOSI      3   // RX pin
    #define LORA_DIO1     40
    #define LORA_RST      42
    #define LORA_BUSY     39
    #define LORA_RXEN     RADIOLIB_NC
    #define LORA_TXEN     RADIOLIB_NC
#endif

// ─── Szenzorok & Spektrum alapértelmezések ──────────────────
#define SENS_RS485_RX_DEFAULT    16
#define SENS_RS485_TX_DEFAULT    17
#define SENS_RS485_DE_DEFAULT    15
#define SENS_SHT_PIN_DEFAULT     18
#define SENS_RAIN_PIN_DEFAULT    34

#define SENS_RS485_BAUD_DEFAULT 9600UL
#define SENS_POLL_INTERVAL_MS    3000UL

// Szenzor bitmask pozicii
#define SENS_BIT_WINDSPEED   0
#define SENS_BIT_WINDDIR     1
#define SENS_BIT_SHT         2
#define SENS_BIT_RAIN        3
#define SENS_BIT_MPU6050     4
#define SENS_BIT_AHT20       5
#define SENS_BIT_BMP280      6
#define SENS_BIT_LTR390      7

// ─── Spektrum / FFT & I2S Paraméterek ──────────────────────
#define FFT_SAMPLES          512
#define FFT_SAMPLING_FREQ    8000.0
#define I2S_PORT             ((i2s_port_t)0)
#define I2S_SCK_PIN          33
#define I2S_WS_PIN           25
#define I2S_SD_PIN           32