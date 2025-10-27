/**
 * @file bluetooth.h
 * @brief Bluetooth command parsing entry point.
 */
#ifndef BLUETOOTH_H
#define BLUETOOTH_H

/**
 * Parse and handle a single Bluetooth command line.
 * Supported commands:
 *  - 0..100 : set throttle percentage
 *  - 1111   : decrease ESC_MAX_US by 100us (clamped)
 *  - 9999   : increase ESC_MAX_US by 100us (clamped)
 *
 * @param command null-terminated ASCII string (modified only for reading)
 */
void parse_BT_commands(char* command);

#endif // BLUETOOTH_H
