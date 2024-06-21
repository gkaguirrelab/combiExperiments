#include "minispect_io.h"
#include "Arduino.h"
#include "Arduino_BuiltIn.h"
#include <Adafruit_AS7341_personal.h>
#include <Adafruit_TSL2591.h>
#include <cstdint>

float calculate_integration_time(uint8_t atime, uint8_t astep) {
    return (atime + 1) * (astep + 1) * 2.78;

}

void read_command(String* input) {
  while(Serial.available() > 0) {
    char incoming_char = Serial.read();
    if(incoming_char == '\n') {
      return ;
    }
    *input += incoming_char;
  }
}

void AS_read(char mode, Adafruit_AS7341* as7341) {
  switch(mode) {
    // Read the Gain 
    case 'G':
        Serial.println("Read AS Gain");
        Serial.println(as7341->getGain());
        break;
    
    // Read the integration time information
    case 'I':
        Serial.println("Read Atime/Astep/Int_time");
        Serial.println(as7341->getATIME());
        Serial.println(as7341->getASTEP()); 
        Serial.println(calculate_integration_time(as7341->getATIME(), as7341->getASTEP()));
        break;
    
    // Read the channels
    case 'C':
        Serial.println("Read AS Channels");
        break;
  }
}

void TS_read(char mode, Adafruit_TSL2591* tsl2591) {
  switch(mode) {
    // Read the Gain 
    case 'G':
        Serial.println("Read TS Gain");
        //Serial.println(as7341.getGain());
        Serial.println(tsl2591->getGain()); 
        break;
    
    // Read the luminosity
    case 'l':
        Serial.println("Read the TS luminosity");
        Serial.println(tsl2591->getFullLuminosity()); 
        break;
    
    // Read the LUX 
    case 'L':
        Serial.println("Read the TS LUX");

        uint32_t lum = tsl2591->getFullLuminosity();
        uint16_t ir, full;
        ir = lum >> 16;
        full = lum & 0xFFFF;
        uint16_t TSL2591_full = full;
        uint16_t TSL2591_ir = ir;
        float TSL2591_lux = tsl2591->calculateLux(full, ir);

        Serial.println(TSL2591_lux);


        break;

  }

}




