/**
 * @file esc_control.h
 * @brief Helpers for writing microsecond pulses to the four ESCs.
 */
#ifndef ESC_CONTROL_H
#define ESC_CONTROL_H

#include <Arduino.h>

/**
 * Set throttle on all motors, clamped to [ESC_MIN_US, ESC_MAX_US].
 * @param us desired pulse width in microseconds
 */
void set_throttle_all(int us);

/**
 * Set throttle for one motor, clamped to [ESC_MIN_US, ESC_MAX_US].
 * Motor index mapping: 1=FL, 2=FR, 3=RR, 4=RL.
 * @param idx motor index 1..4
 * @param us desired pulse width in microseconds
 */
void set_throttle_one(uint8_t idx, int us);

#endif // ESC_CONTROL_H
