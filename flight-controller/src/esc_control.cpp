// esc_control.cpp
// Implements helpers to command ESC pulses. All inputs are clamped to the
// configured min/max ranges to protect the ESCs and avoid accidental overdrive.

#include <Arduino.h>
#include "config.h"
#include "esc_control.h"

void set_throttle_all(int us)
{
  // Clamp to configured range
  if (us < ESC_MIN_US) us = ESC_MIN_US;
  if (us > ESC_MAX_US) us = ESC_MAX_US;

  // Apply to all four ESCs
  ESC_FL.writeMicroseconds(us);
  ESC_FR.writeMicroseconds(us);
  ESC_RR.writeMicroseconds(us);
  ESC_RL.writeMicroseconds(us);
}

void set_throttle_one(uint8_t idx, int us)
{
  // Clamp to configured range
  if (us < ESC_MIN_US) us = ESC_MIN_US;
  if (us > ESC_MAX_US) us = ESC_MAX_US;

  // Route to the selected ESC
  switch (idx) {
    case 1: ESC_FL.writeMicroseconds(us); break; // Front-Left
    case 2: ESC_FR.writeMicroseconds(us); break; // Front-Right
    case 3: ESC_RR.writeMicroseconds(us); break; // Rear-Right
    case 4: ESC_RL.writeMicroseconds(us); break; // Rear-Left
    default: break; // ignore invalid indices
  }
}
