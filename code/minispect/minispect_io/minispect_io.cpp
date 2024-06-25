#include "minispect_io.h"
#include "Arduino.h"
#include "Arduino_BuiltIn.h"
#include <Adafruit_AS7341_personal.h>
#include <Adafruit_TSL2591.h>
#include <LIS2DUXS12Sensor.h>
#include <cstdint>

float calculate_integration_time(uint8_t atime, uint8_t astep) {
    return (atime + 1) * (astep + 1) * 2.78;

}

void sig_error() {
  Serial.println("-1");
  Serial.println("!");
}

void read_command(String* input) {
  while(Serial.available() > 0) {
    char incoming_char = Serial.read();
    
    // If there is an attempt to overload the buffer, throw 
    // an error. buffer size is defined as 3 + MAX_UNSIGNED_VAL_SIZE
    // => 3 + 16
    if(input->length() > 19) {
      sig_error();
      return ;
    }

    // If we receive carriage return (End of Input)
    if(incoming_char == '\n') {
      return ;
    }

    *input += incoming_char;
  }
}

void AS_read(char mode, Adafruit_AS7341* as7341) {
  uint16_t readings[12];
  uint16_t flicker_freq; 

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

      // Read from the Flicker channel
    case 'F':
      flicker_freq = as7341->detectFlickerHz();

      Serial.println(flicker_freq);

      // Append End of Message terminator
      Serial.println("!");

      break; 

    // Invalid command
    default:
      sig_error();
      
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
      sig_error();

      break;
  }

}

void LI_read(char mode, LIS2DUXS12Sensor* lis2duxs12) {
  int32_t accel[3];
  
  lis2duxs12->Get_X_Axes(accel);

  switch(mode) {
    // Read the acceleration information
    case 'A':
      Serial.print("X: ");Serial.println(accel[0]);
      Serial.print("Y: ");Serial.println(accel[1]);
      Serial.print("Z: ");Serial.println(accel[2]);

      // Append End of Message terminator
      Serial.println("!");

      break; 
    
    // Invalid command
    default:
      sig_error();
      break;
  }
}

void SE_read(char mode, NRF_FICR_Type* board_info_reg) {
  uint32_t device_id[2];

  switch(mode) {

    // Read the serial number of the SEEED chip
    case 'S':
      Serial.println("Read Serial Number");

      device_id[0] = board_info_reg->DEVICEID[0];
      device_id[1] = board_info_reg->DEVICEID[1];

      Serial.print(device_id[0], HEX);Serial.println(device_id[1], HEX);
      
      // Append End of Message Terminator
      Serial.println("!");
      break;
    
    // Invalid Command
    default:
      sig_error();
      break;
  }
}


void AS_write(char mode, Adafruit_AS7341* as7341, char* write_val) {
  uint16_t write_val_converted; 
 
 switch(mode) {
    // Write a new gain to the AS chip
    case 'G':
      Serial.println("Writing new gain to AS");

      // Convert the numeric substring of gain -> int
      write_val_converted = atoi(write_val);

      Serial.println(write_val_converted);

      // Keep input within categorical selection bounds
      if(write_val_converted < 0 || write_val_converted > 10) {
        sig_error();
        return ;
      }

      as7341->setGain(as7341_gain_t(write_val_converted));

      // Append End of Message terminator
      Serial.println("!");
      
      break; 

    // Write a new a-time value to AS chip 
    case 'a':
      Serial.println("Writing new a-time to AS");

      // Convert the numeric substring of atime -> int
      write_val_converted = atoi(write_val);
      Serial.println(write_val_converted);
      
      // If the write_val is 0 (invalid for atime/astep) or out of bounds of an 8 bit unsigned int
      if(write_val_converted <= 0 || write_val_converted > 255) {
        sig_error();
        return ;
      }

      as7341->setATIME((uint8_t)write_val_converted); 

      // Append End of Message terminator
      Serial.println("!");
      break;
    
    // Write a new a-step value to AS chip 
    case 'A':
      Serial.println("Writing new a-step to AS");

      // Convert the numeric substring of astep -> int
      write_val_converted = atoi(write_val);
      Serial.println(write_val_converted);
      
      // Check if the write_val is 0 (invalid for atime/astep) or 
      // greater than 999 (max astep val)
      if(write_val_converted <= 0 || write_val_converted > 999) {
        sig_error();
        return ;
      }
      
      as7341->setASTEP(write_val_converted);

      // Append End of Message terminator
      Serial.println("!");
      break;
    
    // Invalid command
    default:
      sig_error();

      break;
    
  }
}

void TS_write(char mode, Adafruit_TSL2591* tsl2591, char* write_val) {
  uint16_t write_val_converted; 
  switch(mode) {
    // Write new gain value 
    case 'G':
      Serial.println("Setting TS gain");

      // Convert the numeric substring of gain -> int 
      write_val_converted = atoi(write_val);

      // Keep the write_val within range of categorical gain choices
      if(write_val_converted < 0 || write_val_converted > 3) {
        sig_error();
        return ; 
      }

      Serial.println(write_val_converted);
      tsl2591->setGain(tsl2591Gain_t(write_val_converted));

      // Append End of Message terminator
      Serial.println("!");
      break;

    // Write new integration time
    case 'I':
      Serial.println("Setting TS integration time");
      
      // Convert the numeric substring of discrete integration time -> int
      write_val_converted = atoi(write_val);

      if(write_val_converted < 0 || write_val_converted > 6) {

      }

      Serial.println(write_val_converted);
      tsl2591->setTiming(tsl2591IntegrationTime_t(write_val_converted));

      // Append End of Message terminator
      Serial.println("!");
    
    // Invalid command
    default:
      sig_error();

      break;

  }
}


