/**
 * @file utils.h
 * @brief Miscellaneous helpers.
 */
#ifndef UTILS_H
#define UTILS_H

/**
 * Print a message to both USB Serial and the HC-05 SoftwareSerial.
 * @param s null-terminated message to print (newline appended)
 */
void print_both_serial(const char* s);

#endif // UTILS_H
