//spectrum_analysis.cpp

#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_MONITOR

#include "spectrum_analysis.h"
#include <driver/i2s.h>
#include <arduinoFFT.h>

extern double currentBands[8];
double currentZCR = 0;

double vReal[FFT_SAMPLES];
double vImag[FFT_SAMPLES];
arduinoFFT FFT = arduinoFFT(vReal, vImag, FFT_SAMPLES, FFT_SAMPLING_FREQ);

bool micCalibrated = false;
int internalMicChannel = 0; // 0 = Bal, 1 = Jobb

void initSpecAna() {
    const i2s_config_t i2s_config = {
        .mode = i2s_mode_t(I2S_MODE_MASTER | I2S_MODE_RX),
        .sample_rate = (uint32_t)FFT_SAMPLING_FREQ,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT, 
        .communication_format = i2s_comm_format_t(I2S_COMM_FORMAT_STAND_I2S),
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 4,
        .dma_buf_len = FFT_SAMPLES,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0
    };

    const i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_SCK_PIN,
        .ws_io_num = I2S_WS_PIN,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = I2S_SD_PIN
    };

    i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
    i2s_set_pin(I2S_PORT, &pin_config);
}

void processChannelFFT(double* inputChannel, double* outputBands, double* outputZCR = nullptr) {
    double mean = 0;
    for (uint16_t i = 0; i < FFT_SAMPLES; i++) {
        vReal[i] = inputChannel[i];
        vImag[i] = 0.0;
        mean += vReal[i];
    }
    mean /= FFT_SAMPLES;

    for (uint16_t i = 0; i < FFT_SAMPLES; i++) {
        vReal[i] -= mean;
    }

    int zcrCount = 0;
    for (uint16_t i = 1; i < FFT_SAMPLES; i++) {
        if ((vReal[i] > 0 && vReal[i-1] <= 0) || (vReal[i] < 0 && vReal[i-1] >= 0)) {
            zcrCount++;
        }
    }
    
    if (outputZCR != nullptr) {
        *outputZCR = (double)zcrCount;
    }

    FFT.Windowing(FFT_WIN_TYP_HAMMING, FFT_FORWARD);
    FFT.Compute(FFT_FORWARD);
    FFT.ComplexToMagnitude();

    int binCounts[8] = {0};
    for (int i = 0; i < 8; i++) {
        outputBands[i] = 0;
    }

    for (uint16_t i = 2; i < (FFT_SAMPLES / 2); i++) {
        double freq = (i * 1.0 * FFT_SAMPLING_FREQ) / FFT_SAMPLES;
        double magnitude = vReal[i] / (FFT_SAMPLES / 2.0); 

        int bandIndex = 0;
        if (freq <= 100) bandIndex = 0;
        else if (freq <= 200) bandIndex = 1;
        else if (freq <= 300) bandIndex = 2;
        else if (freq <= 400) bandIndex = 3;
        else if (freq <= 500) bandIndex = 4;
        else if (freq <= 1000) bandIndex = 5;
        else if (freq <= 3000) bandIndex = 6; 
        else bandIndex = 7; 

        outputBands[bandIndex] += magnitude;
        binCounts[bandIndex]++;
    }

    const float CALIBRATION_OFFSET = 30.0; 
    for (int i = 0; i < 8; i++) {
        if (binCounts[i] > 0) {
            outputBands[i] /= binCounts[i];
        }
        if (outputBands[i] < 1.0) outputBands[i] = 1.0; 
        outputBands[i] = 20.0 * log10(outputBands[i]) - CALIBRATION_OFFSET;
        if (outputBands[i] < 0) outputBands[i] = 0;
    }
}

void updateSpecAna() {
    size_t bytesIn = 0;
    
    static int32_t sampleBuffer[FFT_SAMPLES * 2]; 
    static double leftChannel[FFT_SAMPLES];
    static double rightChannel[FFT_SAMPLES];
    
    i2s_read(I2S_PORT, &sampleBuffer, sizeof(sampleBuffer), &bytesIn, portMAX_DELAY);
    
    for (uint16_t i = 0; i < FFT_SAMPLES; i++) {
        leftChannel[i] = (double)(sampleBuffer[i * 2] >> 8);
        rightChannel[i] = (double)(sampleBuffer[i * 2 + 1] >> 8);
    }

    if (!micCalibrated) {
        double leftBands[8], rightBands[8];
        processChannelFFT(leftChannel, leftBands);
        processChannelFFT(rightChannel, rightBands);

        double leftEnergy = leftBands[0] + leftBands[1] + leftBands[2];
        double rightEnergy = rightBands[0] + rightBands[1] + rightBands[2];

        Serial.printf("Kalibracio - Bal energia: %.1f, Jobb energia: %.1f\n", leftEnergy, rightEnergy);

        if (leftEnergy < 5.0 && rightEnergy > 5.0) {
            internalMicChannel = 1; 
            Serial.println("Csak jobb mikrofon (L/R=3.3V) detektalva.");
        } 
        else if (rightEnergy < 5.0 && leftEnergy > 5.0) {
            internalMicChannel = 0; 
            Serial.println("Csak bal mikrofon (L/R=GND) detektalva.");
        } 
        else if (leftEnergy < 5.0 && rightEnergy < 5.0) {
            internalMicChannel = 0;
            Serial.println("Hiba: Egyik mikrofon sem ad jelet!");
        }
        else {
            double leftIndex = (leftBands[6] + leftBands[7]) / (leftEnergy + 0.1);
            double rightIndex = (rightBands[6] + rightBands[7]) / (rightEnergy + 0.1);

            if (leftIndex < rightIndex) {
                internalMicChannel = 0;
                Serial.println("Ket mikrofon: Bal csatorna a belso.");
            } else {
                internalMicChannel = 1;
                Serial.println("Ket mikrofon: Jobb csatorna a belso.");
            }
        }
        micCalibrated = true;
    }

    if (internalMicChannel == 0) {
        processChannelFFT(leftChannel, currentBands, &currentZCR);
    } else {
        processChannelFFT(rightChannel, currentBands, &currentZCR);
    }
}

#endif // ROLE_MONITOR