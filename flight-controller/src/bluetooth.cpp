// bluetooth.cpp
// Parses simple numeric commands from HC-05 to control ESC throttle:
//  - 0..100 : set throttle to percentage of [ESC_MIN_US, ESC_MAX_US]
//  - 1111   : decrease ESC_MAX_US by 100us (clamped to ESC_MIN_ALLOWED)
//  - 9999   : increase ESC_MAX_US by 100us (clamped to ESC_MAX_ALLOWED)

#include <Arduino.h>
#include <stdlib.h>
#include <stdio.h>
#include "config.h"
#include "esc_control.h"
#include "utils.h"
#include "bluetooth.h"

void parse_BT_commands(char* command)
{
  // Trim leading whitespace for robustness
  while (*command == ' ' || *command == '\t') command++;
  if (*command == '\0') return;

  // percentage 0..100 or special numeric commands
  char* endp = NULL;
  long throttle_value = strtol(command, &endp, 10);

  if (endp && *endp == '\0') {

    if (throttle_value == 1111) {
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

    else if (throttle_value == 9999) {
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
    
    else if (throttle_value >= 0 && throttle_value <= 100) {
      ESC_current_pct = (int)throttle_value;
      int us = ESC_MIN_US + (int)((ESC_MAX_US - ESC_MIN_US) * (ESC_current_pct / 100.0));
      set_throttle_all(us);
      
      char msg[64];
      snprintf(msg, sizeof(msg), "throttle_value -> %ld%%  => %dus", throttle_value, us);
      print_both_serial(msg);
      return;
    }
    print_both_serial("ERR: unknown command");
  }
}
