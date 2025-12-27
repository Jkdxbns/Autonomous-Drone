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

    // Attach ESC servo outputs to their pins
    ESC_FL.attach(PIN_ESC_FL);
    ESC_FR.attach(PIN_ESC_FR);
    ESC_RR.attach(PIN_ESC_RR);
    ESC_RL.attach(PIN_ESC_RL);
    delay(50);

    // Send a brief MAX signal to let ESCs enter programming/arming as needed,
    // then fall back to MIN. Adjust timings to match your ESCs if necessary.
    set_throttle_all(ESC_MAX_US);
    print_both_serial("BOOT: MAX throttle sent for ESC programming.");
    delay(2000);
    set_throttle_all(ESC_MIN_US);
    print_both_serial("BOOT: MIN throttle sent.");
    delay(1000);
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
