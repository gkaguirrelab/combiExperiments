#include "Arduino.h"
#include "Arduino_BuiltIn.h"

// Read a command from the serial input and populate 
// input buffer
void read_command(String* serial_input);

// Read various information (as specified by input) from the ASM7341 chip
void AS_read();

// Read various information (as specified by input) from the TSL2591 chip
void TS_read(); 

// Write various information (as specified by input) from the ASM7341 chip
void AS_write(); 

// Write various information (as specified by input) from the TSL2591 chip
void TS_write(); 

