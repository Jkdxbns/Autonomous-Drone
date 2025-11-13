// main.cpp
// Entry point for the application: sets up peripherals and processes
// Bluetooth commands in the loop. Kept small; logic lives in modules.

#include <Arduino.h>
#include "config.h"
#include "utils.h"
#include "esc_control.h"
#include "bluetooth.h"

// Simple line buffer for BT commands (kept local to this file).
// HC-05 typically sends CR/LF on line end; we treat either as a terminator.
static char lineBuf[48];
static uint8_t lineLen = 0;

void setup()
{
    // Initialize serial links
    Serial.begin(BAUDRATE);
    HC05.begin(BAUDRATE);

    // Attach ESC servo outputs to their pins with proper pulse range
    ESC_FL.attach(PIN_ESC_FL, ESC_MIN_ALLOWED, ESC_MAX_ALLOWED);
    ESC_FR.attach(PIN_ESC_FR, ESC_MIN_ALLOWED, ESC_MAX_ALLOWED);
    ESC_RR.attach(PIN_ESC_RR, ESC_MIN_ALLOWED, ESC_MAX_ALLOWED);
    ESC_RL.attach(PIN_ESC_RL, ESC_MIN_ALLOWED, ESC_MAX_ALLOWED);
    delay(50);

    // ESC Calibration: Send MAX (2000µs) then MIN (1000µs)
    // This teaches ESCs their throttle range - bypass set_throttle_all() clamping
    ESC_FL.writeMicroseconds(ESC_MAX_ALLOWED);
    ESC_FR.writeMicroseconds(ESC_MAX_ALLOWED);
    ESC_RR.writeMicroseconds(ESC_MAX_ALLOWED);
    ESC_RL.writeMicroseconds(ESC_MAX_ALLOWED);
    print_both_serial("BOOT: Sending MAX (2000us) for ESC calibration...");
    delay(2000);  // Wait for ESC to recognize max and beep
    
    ESC_FL.writeMicroseconds(ESC_MIN_ALLOWED);
    ESC_FR.writeMicroseconds(ESC_MIN_ALLOWED);
    ESC_RR.writeMicroseconds(ESC_MIN_ALLOWED);
    ESC_RL.writeMicroseconds(ESC_MIN_ALLOWED);
    print_both_serial("BOOT: Sending MIN (1000us) for ESC calibration...");
    delay(3000);  // Wait for calibration complete beeps
    print_both_serial("BOOT: POST Complete. Drone ready.");
}


void loop()
{
    // Drain the Bluetooth serial into a small buffer and parse by line
    while (HC05.available())
    {
        char c = (char)HC05.read();
        if (c == '\r' || c == '\n')
        {
            if (lineLen > 0)
            {
                lineBuf[lineLen] = '\0';
                parse_BT_commands(lineBuf);
                lineLen = 0;
            }
        }
        else if (lineLen < sizeof(lineBuf) - 1)
        {
            lineBuf[lineLen++] = c;
        }
    }
}
