// utils.cpp
// Small shared helpers used across modules.

#include <Arduino.h>
#include "config.h"
#include "utils.h"

void print_both_serial(const char* s)
{
  // Mirror log lines to both Serial (USB) and HC-05 (Bluetooth)
  Serial.println(s);
  HC05.println(s);
}
