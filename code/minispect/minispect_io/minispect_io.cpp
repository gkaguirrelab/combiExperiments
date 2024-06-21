#include "minispect_io.h"
#include "Arduino.h"
#include "Arduino_BuiltIn.h"

void read_command(String* input) {
  while(Serial.available() > 0) {
    char incoming_char = Serial.read();
    if(incoming_char == '\n') {
      return ;
    }
    *input += incoming_char;
  }
}



