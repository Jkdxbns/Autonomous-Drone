// config.cpp
// Definitions for globals declared in config.h

#include "config.h"

// Runtime-adjustable ESC pulse limits and state
int ESC_MIN_US = ESC_MIN_ALLOWED;
int ESC_MAX_US = ESC_MAX_ALLOWED * 0.2; // Start with 20% max for safety
int ESC_current_pct = 0; // 0..100

// Peripherals
SoftwareSerial HC05(PIN_BT_RX, PIN_BT_TX); // RX, TX
Servo ESC_FL;
Servo ESC_FR;
Servo ESC_RR;
Servo ESC_RL;
