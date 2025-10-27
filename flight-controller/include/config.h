/**
 * @file config.h
 * @brief Shared configuration: pins, baud rate, limits, and global peripherals.
 *
 * This header centralizes hardware mappings and globals so modules can
 * include a single file for consistent configuration.
 */
#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>
#include <SoftwareSerial.h>
#include <Servo.h>

// Serial speed for both USB Serial and HC-05
#define BAUDRATE 9600

// Bluetooth pins (Arduino Nano)
#define PIN_BT_RX 10 // D10 -> RX from HC-05 TX
#define PIN_BT_TX 11 // D11 -> TX to HC-05 RX

// Motor signal pins
// Quad outputs on D3..D6: FL=D3, FR=D4, RR=D5, RL=D6
#define PIN_ESC_FL 3 // D3
#define PIN_ESC_FR 4 // D4
#define PIN_ESC_RR 5 // D5
#define PIN_ESC_RL 6 // D6

// ESC timing (typical)
#define ESC_MIN_ALLOWED 1000  // us
#define ESC_MAX_ALLOWED 2000  // us

// Adjustable runtime parameters
extern int ESC_MIN_US;        // minimum effective microseconds
extern int ESC_MAX_US;        // current allowed max, adjustable by commands
extern int ESC_current_pct;   // last commanded percentage (0..100)

// Peripherals (instantiated in config.cpp)
extern SoftwareSerial HC05;   // RX, TX
extern Servo ESC_FL;
extern Servo ESC_FR;
extern Servo ESC_RR;
extern Servo ESC_RL;

#endif // CONFIG_H
