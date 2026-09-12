//spectrum_analysis.h

#pragma once
#include <Arduino.h>
#include "config.h"

#if CURRENT_DEVICE_ROLE == ROLE_MONITOR

extern double currentBands[8];
extern double currentZCR; 

void initSpecAna();
void updateSpecAna();

#endif // ROLE_MONITOR