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

    // Invalid command
    default:
      Serial.println("-1");
      
      break;
  }
}

void TS_read(char mode, Adafruit_TSL2591* tsl2591) {
  uint32_t lum;
  uint16_t ir, full;
  uint16_t TSL2591_full, TSL2591_ir; 
  float TSL2591_lux; 
  
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

        lum = tsl2591->getFullLuminosity();
        ir, full;
        ir = lum >> 16;
        full = lum & 0xFFFF;
        TSL2591_full = full;
        TSL2591_ir = ir;
        TSL2591_lux = tsl2591->calculateLux(full, ir);

        Serial.println(TSL2591_lux);


        break;

    // Invalid command
    default: 
      Serial.println("-1");

      break;
  }

}


void AS_write(char mode, Adafruit_AS7341* as7341, char* write_val) {
  switch(mode) {
    // Write a new gain to the AS chip
    case 'G':
      Serial.println("Writing new gain to AS");

      // Convert the numeric substring of gain -> int
      Serial.println(atoi(write_val));
      as7341->setGain(as7341_gain_t(atoi(write_val)));
  
      
      break; 

    // Write a new a-time vcalue to AS chip 
    case 'a':
      Serial.println("Writing new a-time to AS");

      // Convert the numeric substring of atime -> int
      Serial.println(atoi(write_val));
      as7341->setATIME((uint8_t)  atoi(write_val)); 

      break;
    
    // Write a new a-step vcalue to AS chip 
    case 'A':
      Serial.println("Writing new a-step to AS");

      // Convert the numeric substring of astep -> int
      Serial.println(atoi(write_val));
      as7341->setASTEP((uint16_t) atoi(write_val));

      break;
    
    // Invalid command
    default:
      Serial.println("-1");

      break;
    
  }
}

void TS_write(char mode, Adafruit_TSL2591* tsl2591, char* write_val) {
  switch(mode) {
    // Write new gain value 
    case 'G':
      Serial.println("Setting TS gain");

      // Convert the numeric substring of gain -> int 
      Serial.println(atoi(write_val));
      tsl2591->setGain(tsl2591Gain_t(atoi(write_val)));
      break;

    // Write new integration time
    case 'I':
      Serial.println("Setting TS integration time");
      
      // Convert the numeric substring of discrete integration time -> int
      Serial.println(atoi(write_val));
      tsl2591->setTiming(tsl2591IntegrationTime_t(atoi(write_val)));
    
    // Invalid command
    default:
      Serial.println("-1");

      break;

  }
}


