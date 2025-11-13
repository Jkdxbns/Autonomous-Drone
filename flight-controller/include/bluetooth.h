/**
 * @file bluetooth.h
 * @brief Bluetooth command parsing entry point.
 */
#ifndef BLUETOOTH_H
#define BLUETOOTH_H

/**
 * Parse and handle a single Bluetooth command line.
 * Supported commands:
 *  - throttle:0..100 : set throttle percentage
 *  - limit_decrease  : decrease ESC_MAX_US by 100us (clamped)
 *  - limit_increase  : increase ESC_MAX_US by 100us (clamped)
 *  - e-stop          : emergency stop - immediately set all motors to 0%
 *
 * @param command null-terminated ASCII string (modified only for reading)
 */
void parse_BT_commands(char* command);

#endif // BLUETOOTH_H
