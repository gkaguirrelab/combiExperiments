#include "Arduino.h"
#include "Arduino_BuiltIn.h"
#include <Adafruit_AS7341_personal.h>
#include <Adafruit_TSL2591.h>

// Read a command from the serial input and populate 
// input buffer
void read_command(String* serial_input);

// Read various information (as specified by input) from the ASM7341 chip
void AS_read(char mode, Adafruit_AS7341* as7341);

// Read various information (as specified by input) from the TSL2591 chip
void TS_read(char mode, Adafruit_TSL2591* tsl2591);

// Write various information (as specified by input) from the ASM7341 chip
void AS_write(char mode, Adafruit_AS7341* as7341, char* write_val);

// Write various information (as specified by input) from the TSL2591 chip
void TS_write(char mode, Adafruit_TSL2591* tsl2591, char* write_val); 

