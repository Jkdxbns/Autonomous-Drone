// bluetooth.cpp
// Parses commands from HC-05 to control ESC throttle:
//  - throttle:0..100 : set throttle to percentage of [ESC_MIN_US, ESC_MAX_US]
//  - limit_decrease  : decrease ESC_MAX_US by 100us (clamped to ESC_MIN_ALLOWED)
//  - limit_increase  : increase ESC_MAX_US by 100us (clamped to ESC_MAX_ALLOWED)
//  - e-stop          : emergency stop - immediately set all motors to 0% throttle

#include <Arduino.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "config.h"
#include "esc_control.h"
#include "utils.h"
#include "bluetooth.h"

void parse_BT_commands(char *command)
{
  // Trim leading whitespace for robustness
  while (*command == ' ' || *command == '\t') command++;
  if (*command == '\0') return;

  // Echo received command
  char msg[64];
  snprintf(msg, sizeof(msg), "BT Command: %s", command);
  print_both_serial(msg);

  // Check for limit_decrease command
  if (strcmp(command, "-100") == 0) {
    // Decrease max by 100us and clamp
    ESC_MAX_US -= 100;
    if (ESC_MAX_US < ESC_MIN_ALLOWED) ESC_MAX_US = ESC_MIN_ALLOWED;

    int us = ESC_MIN_US + (int)((ESC_MAX_US - ESC_MIN_US) * (ESC_current_pct / 100.0));
    set_throttle_all(us);

    char msg[64];
    snprintf(msg, sizeof(msg), "MAX throttle decreased -> %dus", ESC_MAX_US);
    print_both_serial(msg);
    return;
  }

  // Check for limit_increase command
  if (strcmp(command, "+100") == 0) {
    // Increase max by 100us and clamp
    ESC_MAX_US += 100;
    if (ESC_MAX_US > ESC_MAX_ALLOWED) ESC_MAX_US = ESC_MAX_ALLOWED;

    int us = ESC_MIN_US + (int)((ESC_MAX_US - ESC_MIN_US) * (ESC_current_pct / 100.0));
    set_throttle_all(us);

    char msg[64];
    snprintf(msg, sizeof(msg), "MAX throttle increased -> %dus", ESC_MAX_US);
    print_both_serial(msg);
    return;
  }

  // Check for e-stop command
  if (strcmp(command, "e-stop") == 0) {
    // Emergency stop - immediately set all motors to 0%
    ESC_current_pct = 0;
    set_throttle_all(ESC_MIN_US);
    print_both_serial("EMERGENCY STOP - All motors set to 0%");
    return;
  }

  // Check for throttle:N command (N = 0..100)
  if (strncmp(command, "t:", 2) == 0) {
    char* value_str = command + 2;
    char* endp = NULL;
    long throttle_value = strtol(value_str, &endp, 10);

    if (endp && *endp == '\0' && throttle_value >= 0 && throttle_value <= 100) {
      ESC_current_pct = (int)throttle_value;
      int us = ESC_MIN_US + (int)((ESC_MAX_US - ESC_MIN_US) * (ESC_current_pct / 100.0));
      set_throttle_all(us);
      
      char msg[64];
      snprintf(msg, sizeof(msg), "Throttle -> %ld%%  => %dus", throttle_value, us);
      print_both_serial(msg);
      return;
    }
  }

  print_both_serial("ERR: unknown command");
}
