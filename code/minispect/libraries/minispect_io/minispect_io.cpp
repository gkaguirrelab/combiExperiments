#include "minispect_io.h"
#include "Arduino.h"
#include "Arduino_BuiltIn.h"
#include <Adafruit_AS7341.h>
#include <Adafruit_TSL2591.h>
#include <LIS2DUXS12Sensor.h>
#include <cstdint>
#include <set>
#include <vector>
#include <HardwareBLESerial.h>

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

void read_BLE_command(String* input, HardwareBLESerial* bleSerial) {
  char ble_read_buffer[19];
  bleSerial->poll();

  // If there is an attempt to overload the buffer, throw 
  // an error. buffer size is defined as 3 + MAX_UNSIGNED_VAL_SIZE
  // => 3 + 16
  while (bleSerial->availableLines() > 0) {
    bleSerial->readLine(ble_read_buffer, 19);
  }

  *input = String(ble_read_buffer);

}

void write_ble(HardwareBLESerial* bleSerial, 
               std::vector<uint16_t>* AS_channels,
               std::vector<uint16_t>* TS_channels,
               std::vector<int32_t>* LI_channels,
               float LI_temp) 
{
    //Can transfer 52 bytes total
    uint8_t dataBLE[52];
    int i = 2;  
    
    // 2 bytes at the start for beginning flag
    dataBLE[0] = ':';
    dataBLE[1] = 'D';

    // Copy over AS_channel bytes
    //11 * 2 bytes from AS channels -> 22 
    for(i; i < AS_channels->size(); i+=2) {
      std::memcpy(&dataBLE[i], &AS_channels->at(i), sizeof(uint16_t));
    }

    //Copy over the TS channel bytes
    //2 x 2 bytes from TS channels -> 4
    for(i; i < TS_channels->size(); i+=2) {
      std::memcpy(&dataBLE[i], &TS_channels->at(i), sizeof(uint16_t));
    }

    //Copy over the LI channel bytes
    //3 x 4 bytes from LI channels - > 12 
    for(i; i < LI_channels->size(); i+=2) {
      std::memcpy(&dataBLE[i], &LI_channels->at(i), sizeof(int32_t));
    }

    //Copy over the LI temperature
    //1 x 4 bytes from LI_temp - > 4 
    std::memcpy(&dataBLE[i], &LI_temp, sizeof(float));
  
    // Send data back to caller over BLE
    for (int i = 0; i < 52; i++) {
        bleSerial->write(dataBLE[i]);
    }
                                // + 1 byte at the end for end
    // Total                    45 Bytes
    
    // Reset the buffer
    bleSerial->flush();
    memset(dataBLE, '\0', 40);
    dataBLE[0] = ':';
    dataBLE[1] = 'D';
    dataBLE[51] = '\n';
}


std::vector<uint16_t> AS_read(char mode, Adafruit_AS7341* as7341) {
  uint16_t readings[12];
  uint16_t flicker_freq; 
  std::vector<uint16_t> result; 

  switch(mode) {
    // Read the Gain 
    case 'G':
        Serial.println("Read AS Gain");
        Serial.println(as7341->getGain());

        // Append End of Message terminator
        Serial.println("!");
        break;
    
    // Read the ATIME
    case 'a':
        Serial.println("Read Atime");
        Serial.println(as7341->getATIME());
  

        // Append End of Message terminator
        Serial.println("!");
        break;

    // Read the ASTEP
    case 'A':
      Serial.println("Read Astep");
      Serial.println(as7341->getASTEP()); 

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
          break;
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
        
        // Append readings to result vector
        for(int i = 0; i < 12; i++) {
          result.push_back(readings[i]);
        }

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

  return result;
}

std::vector<uint16_t> TS_read(char mode, Adafruit_TSL2591* tsl2591) {
  uint32_t lum;
  uint16_t ir, full;
  uint16_t TSL2591_full, TSL2591_ir; 
  float TSL2591_lux;
  std::vector<uint16_t> result;  
  
  switch(mode) {
    // Read the Gain 
    case 'G':
        Serial.println("Read TS Gain");
        //Serial.println(as7341.getGain());
        Serial.println(tsl2591->getGain()); 

        // Append End of Message terminator
        Serial.println("!");
        break;
    
    // Read all channels
    case 'C':
        Serial.println("Read TS channels");
        lum = tsl2591->getFullLuminosity();
        
        ir = lum >> 16;
        full = lum & 0xFFFF;
        TSL2591_full = full;
        TSL2591_ir = ir;

        Serial.print("Channel 0 : "); Serial.println(full);
        Serial.print("Channel 1 : "); Serial.println(ir);
        
        // Append channel readings to result
        result.push_back(full);
        result.push_back(ir);

        // Append End of Message terminator
        Serial.println("!");
        break;  
    
    // Read the integration time
    case 'A':
      Serial.println("Read TS Integration Time");
      
      Serial.println(tsl2591->getTiming());

      // Append End of Message terminator
      Serial.println("!");
      break;   

    // Read the LUX 
    case 'L':
        Serial.println("Read the TS LUX");

        lum = tsl2591->getFullLuminosity();
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

  return result; 

}

std::vector<int32_t> LI_read(char mode, LIS2DUXS12Sensor* lis2duxs12) {
  int32_t accel[3];
  float_t temperature; 
  std::vector<int32_t> result; 
  
  lis2duxs12->Get_X_Axes(accel);

  switch(mode) {
    // Read the acceleration information
    case 'A':
      Serial.print("X : ");Serial.println(accel[0]);
      Serial.print("Y : ");Serial.println(accel[1]);
      Serial.print("Z : ");Serial.println(accel[2]);

      // Append acceleration information to the result vector
      for(int i = 0; i < 3; i++) {
        result.push_back(accel[i]); 
      }

      // Append End of Message terminator
      Serial.println("!");
      break; 
    
    // Read the temperature 
    case 'T':
      // If there was a problem with reading the temperature, throw an error 
      if(lis2duxs12->Get_Temp(&temperature) != LIS2DUXS12_STATUS_OK) {
        sig_error();
        break; 
      }

      // Print out the temperature reading (C)
      Serial.println(temperature);

      // Append temperature to the result vector 
      result.push_back(temperature);

      // Append End of Message terminator
      Serial.println("!");
      break; 

    // Invalid command
    default:
      sig_error();
      break;
  }

  return result; 
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

    // Write a power setting to the AS chip
    case 'P':
      Serial.println("Writing power value to AS"); 

      // Convert the numeric substring of astep -> int
      write_val_converted = atoi(write_val);
      Serial.println(write_val_converted);

      // If the write val was not a boolean 
      if(write_val_converted < 0 || write_val_converted > 1) {
        sig_error();
        return;
      }

      // Toggle the AS7341 power
      as7341->powerEnable(write_val_converted);

      // Append End of Message Terminator
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

  std::vector<int> valid_gain_valvec = {0,16,32,48};
  std::set<int> valid_gain_settings(valid_gain_valvec.begin(),valid_gain_valvec.end());

  switch(mode) {
    // Write new gain value 
    case 'G':
      Serial.println("Setting TS gain");

      // Convert the numeric substring of gain -> int 
      write_val_converted = atoi(write_val);

      // Keep the write_val within range of categorical gain choices
      if(write_val_converted < 0 || 
        valid_gain_settings.find(write_val_converted) == valid_gain_settings.end() ) 
      {
        sig_error();
        return ; 
      }

      Serial.println(write_val_converted);
      tsl2591->setGain(tsl2591Gain_t(write_val_converted));

      // Append End of Message terminator
      Serial.println("!");
      break;

    // Write new integration time (A is for ATIME, to try and make
    // this somewhat equivalent in design to AS_write which has 
    // more ATIME and ASTEP write to construct integration time)
    case 'A':
      Serial.println("Setting TS integration time");
      
      // Convert the numeric substring of discrete integration time -> int
      write_val_converted = atoi(write_val);

      if(write_val_converted < 0 || write_val_converted > 5) {
        sig_error();
        return;
      }

      Serial.println(write_val_converted);
      tsl2591->setTiming(tsl2591IntegrationTime_t(write_val_converted));

      // Append End of Message terminator
      Serial.println("!");

      break;

    // Write a power setting to the TS chip
    case 'P':
      Serial.println('Writing power value to TS');

      // Convert the numeric substring of discrete integration time -> int
      write_val_converted = atoi(write_val);

      // If the power setting was not a boolean
      if(write_val_converted < 0 || write_val_converted > 1) {
        sig_error();
        return ;
      }

      // Toggle the power 
      if(write_val_converted == 1) {
        tsl2591->enable();
      }
      else {
        tsl2591->disable();
      }

      // Append End of Message Terminator
      Serial.println("!");  
      break;

    
    // Invalid command
    default:
      sig_error();

      break;

  }
}

void LI_write(char mode, LIS2DUXS12Sensor* lis2duxs12, char* write_val) {
  uint16_t write_val_converted; 
  switch(mode) {
    case 'P':
      Serial.println("Writing power value to LI chip");

      // Convert the numeric substring to numeric value
      write_val_converted = atoi(write_val);

      if(write_val_converted < 0 || write_val_converted > 1) {
        sig_error();
        return ;
      }

      if(write_val_converted == 1) {
        lis2duxs12->begin();
      }
      else {
        lis2duxs12->end();
      }

      // Append End of Message terminator
      Serial.println("!");
      break;
  }

}

