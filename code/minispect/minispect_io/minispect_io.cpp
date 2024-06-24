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
  uint16_t readings[12];

  switch(mode) {
    // Read the Gain 
    case 'G':
        Serial.println("Read AS Gain");
        Serial.println(as7341->getGain());

        // Append End of Message terminator
        Serial.println("!");
        break;
    
    // Read the integration time information
    case 'I':
        Serial.println("Read Atime/Astep/Int_time");
        Serial.println(as7341->getATIME());
        Serial.println(as7341->getASTEP()); 
        Serial.println(calculate_integration_time(as7341->getATIME(), as7341->getASTEP()));

        // Append End of Message terminator
        Serial.println("!");

        break;
    
    // Read the channels
    case 'C':
        Serial.println("Read AS Channels");
        
        // If unable to read channels, report error
        if (!as7341->readAllChannels(readings)) {
          Serial.println("-1");
          Serial.println("!");
          return;
        }

        // Print out the channel readings
        Serial.print("ADC0/F1 415nm : ");
        Serial.println(readings[0]);
        Serial.print("ADC1/F2 445nm : ");
        Serial.println(readings[1]);
        Serial.print("ADC2/F3 480nm : ");
        Serial.println(readings[2]);
        Serial.print("ADC3/F4 515nm : ");
        Serial.println(readings[3]);
        Serial.print("ADC0/F5 555nm : ");
        Serial.println(readings[6]);
        Serial.print("ADC1/F6 590nm : ");
        Serial.println(readings[7]);
        Serial.print("ADC2/F7 630nm : ");
        Serial.println(readings[8]);
        Serial.print("ADC3/F8 680nm : ");
        Serial.println(readings[9]);
        Serial.print("ADC4/Clear    : ");
        Serial.println(readings[10]);
        Serial.print("ADC5/NIR      : ");
        Serial.println(readings[11]);
        
        // Append End of Message terminator
        Serial.println("!");
        
        break;

    // Invalid command
    default:
      Serial.println("-1");
      Serial.println("!");
      
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

        // Append End of Message terminator
        Serial.println("!");
        break;
    
    // Read the luminosity
    case 'l':
        Serial.println("Read the TS luminosity");
        Serial.println(tsl2591->getFullLuminosity()); 

        // Append End of Message terminator
        Serial.println("!");
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


        // Append End of Message terminator
        Serial.println("!");

        break;

    // Invalid command
    default: 
      Serial.println("-1");
      Serial.println("!");

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

      // Append End of Message terminator
      Serial.println("!");
      
      break; 

    // Write a new a-time value to AS chip 
    case 'a':
      Serial.println("Writing new a-time to AS");

      // Convert the numeric substring of atime -> int
      Serial.println(atoi(write_val));
      as7341->setATIME((uint8_t)  atoi(write_val)); 

      // Append End of Message terminator
      Serial.println("!");
      break;
    
    // Write a new a-step value to AS chip 
    case 'A':
      Serial.println("Writing new a-step to AS");

      // Convert the numeric substring of astep -> int
      Serial.println(atoi(write_val));
      as7341->setASTEP((uint16_t) atoi(write_val));

      // Append End of Message terminator
      Serial.println("!");
      break;
    
    // Invalid command
    default:
      Serial.println("-1");
      Serial.println("!");

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

      // Append End of Message terminator
      Serial.println("!");
      break;

    // Write new integration time
    case 'I':
      Serial.println("Setting TS integration time");
      
      // Convert the numeric substring of discrete integration time -> int
      Serial.println(atoi(write_val));
      tsl2591->setTiming(tsl2591IntegrationTime_t(atoi(write_val)));

      // Append End of Message terminator
      Serial.println("!");
    
    // Invalid command
    default:
      Serial.println("-1");
      Serial.println("!");
      break;

  }
}


