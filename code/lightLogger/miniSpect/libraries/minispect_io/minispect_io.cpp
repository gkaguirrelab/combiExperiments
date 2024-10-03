#include "minispect_io.h"
#include "Arduino.h"
#include "Arduino_BuiltIn.h"
#include <Adafruit_AS7341.h>
#include <Adafruit_TSL2591.h>
#include <LSM6DSV16XSensor.h>
#include <cstdint>
#include <set>
#include <vector>
#include <HardwareBLESerial.h>
#include <cstddef> 

// Calculate the integration time for the AMS7341 chip
float calculate_integration_time(uint8_t atime, uint8_t astep) {
    return (atime + 1) * (astep + 1) * 2.78;

}

// Signal an error over the serial port
void sig_error() {
  Serial.println("-1");
  Serial.println("!");
}

// Read a command over the serial port
// and populate the inpute string with 
// the command
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

    // Append the character to the input string
    *input += incoming_char;
  }
}
// Read a command over bluetooth, populating the input string
void read_BLE_command(String* input, HardwareBLESerial* bleSerial) {
  // Initialize empty buffer to read command
  char ble_read_buffer[19] = "\0"; 

  // Poll the BLE connection
  bleSerial->poll();

  // If there is an attempt to overload the buffer, throw 
  // an error. buffer size is defined as 3 + MAX_UNSIGNED_VAL_SIZE
  // => 3 + 16
  while (bleSerial->availableLines() > 0) {
    bleSerial->readLine(ble_read_buffer, 19);
  }

  // If the command is not null, append set input equal 
  // to the command received
  if(ble_read_buffer[0] != '\0') {
    *input = String(ble_read_buffer);
  }

}

// Write data from all sensors over the serial port
void write_serial(std::vector<uint16_t>* AS_channels,
                  std::vector<uint16_t>* TS_channels,
                  std::vector<int16_t>* accel_buffer,
                  std::vector<int16_t>* angrate_buffer,
                  float_t LS_temp) 
{

    // Define a vector that is the total size of all of the buffers, the temperature, and the separators
    std::vector<uint8_t> data_buffer; 
    uint64_t total_bytes = (AS_channels->size() * sizeof(uint16_t)) + (TS_channels->size() * sizeof(uint16_t)); 
                          + (accel_buffer->size() * sizeof(int16_t)) + (angrate_buffer->size() * sizeof(int16_t))
                          + (1 * sizeof(float_t))
                          + (2 * sizeof(char));
    data_buffer.reserve(total_bytes);

    // Set the beginning and ending terminators 
    data_buffer[0] = '<';
    data_buffer[data_buffer.capacity()-1] = '>';

    // Copy over the elements from all of the buffers
    uint8_t* start = reinterpret_cast<uint8_t*>(AS_channels->data());
    uint8_t* end = reinterpret_cast<uint8_t*>(AS_channels->data() + AS_channels->size());
    data_buffer.insert(data_buffer.end(), start, end);

    start = reinterpret_cast<uint8_t*>(TS_channels->data());
    end = reinterpret_cast<uint8_t*>(TS_channels->data() + TS_channels->size());
    data_buffer.insert(data_buffer.end(), start, end);

    start = reinterpret_cast<uint8_t*>(accel_buffer->data());
    end = reinterpret_cast<uint8_t*>(accel_buffer->data() + accel_buffer->size());
    data_buffer.insert(data_buffer.end(), start, end);

    start = reinterpret_cast<uint8_t*>(angrate_buffer->data());
    end = reinterpret_cast<uint8_t*>(angrate_buffer->data() + angrate_buffer->size());
    data_buffer.insert(data_buffer.end(), start, end);

    start = reinterpret_cast<uint8_t*>(&LS_temp);
    end = reinterpret_cast<uint8_t*>(&LS_temp + sizeof(float_t));
    data_buffer.insert(data_buffer.end(), start, end);

    // Write it throught the serial port
    Serial.write(data_buffer.data(), data_buffer.size());

}

// Write data from all sensors over the BLE connection
void write_ble(HardwareBLESerial* bleSerial, 
               std::vector<uint16_t>* AS_channels,
               std::vector<uint16_t>* TS_channels,
               int16_t* accel_buffer,
               float_t LS_temp) 
{
    //Can transfer 175 bytes total
    uint8_t dataBLE[175];
    int pos = 2;  
    
    // 2 bytes at the start for beginning flag
    memset(dataBLE, '\0', 175);
    dataBLE[0] = ':';
    dataBLE[1] = 'D';

    // One byte at the end for ending flag
    dataBLE[174] = '\n';

    // Copy over AS_channel bytes
    //11 * 2 bytes from AS channels -> 22 
    for(int i = 0; i < AS_channels->size(); i++) {
      std::memcpy(&dataBLE[pos], &AS_channels->at(i), sizeof(uint16_t));
      pos += 2; 
    }

    //Copy over the TS channel bytes
    //2 x 2 bytes from TS channels -> 4
    for(int i = 0; i < TS_channels->size(); i++) {
      std::memcpy(&dataBLE[pos], &TS_channels->at(i), sizeof(uint16_t));
      pos += 2; 
    }

    //Copy over the LI channel bytes
    //20 x 3 * 2 bytes from LI channels - > 120 
    int buffer_size = 60; //sizeof(accel_buffer) / sizeof(int16_t);
    std::memcpy(&dataBLE[pos], accel_buffer, buffer_size * sizeof(int16_t));

    Serial.print("ACCEL BUFFER SIZE: ");Serial.println(buffer_size);
    pos += (buffer_size * 2); 

    //Copy over the LS temperature
    //1 x 4 bytes from LS_temp - > 4 OR 8, not sure of float_t 
    std::memcpy(&dataBLE[pos], &LS_temp, sizeof(float_t));
  
    // Send data back to caller over BLE
    for (int i = 0; i < 175; i++) {
        bleSerial->write(dataBLE[i]);
    }
                                // + 1 byte at the end for end
    // Total                    45 Bytes
    
    // Reset the buffer
    bleSerial->flush();
}

// Read from the AS chip with a given mode
std::vector<uint16_t> AS_read(char mode, Adafruit_AS7341* as7341,
                              char device_mode) 
{
  // Initialize channel readings buffer, potential variables, 
  // and return vector
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
        // If unable to read channels, report error
        if (!as7341->readAllChannels(readings)) {
          Serial.println("-1");
          Serial.println("!");
          break;
        }

        // If we are in science mode, simply 
        // append to vector and return
        if(device_mode == 'S') {
        // Append readings to result vector
          for(int i = 0; i < 12; i++) {
            if(i == 4 || i == 5){
              continue;
            }
            result.push_back(readings[i]);
          }
          break; 
        }

        // Print out the channel readings
        Serial.println("Read AS Channels");
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

      // If we are in science mode simply return
      if(device_mode == 'S') {
        // Append flicker to result vector
        result.push_back(flicker_freq);
        break; 
      }

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

// Read from the TS chip with a given mode
std::vector<uint16_t> TS_read(char mode, Adafruit_TSL2591* tsl2591,
                              char device_mode) 
{
  // Initialize variables to use later and return vector
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
        lum = tsl2591->getFullLuminosity();
        
        ir = lum >> 16;
        full = lum & 0xFFFF;
        TSL2591_full = full;
        TSL2591_ir = ir;

        // If we are in science mode, simply append 
        // results and break 
        if(device_mode == 'S') {
          // Append channel readings to result
          result.push_back(full);
          result.push_back(ir);

          break; 
        }

        Serial.println("Read TS channels");
 
        Serial.print("Channel 0 : "); Serial.println(full);
        Serial.print("Channel 1 : "); Serial.println(ir);
        

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

// Read from the LS chip with a given mode
std::vector<float_t> LS_read(char mode, LSM6DSV16XSensor* lsm6dsv16x,
                             char device_mode, bool verbose) 
{
  // Initialize buffer for acceleration/angle rate values
  // and variable for sensor temperature, as well
  // as the return vector
  int32_t accel[3], angrate[3];
  int16_t temperature; 
  std::vector<float_t> result; 

  switch(mode) {
    // Read the acceleration information
    case 'A':
      // Retrieve the sensor values
      lsm6dsv16x->Get_X_Axes(accel);
      lsm6dsv16x->Get_G_Axes(angrate);

      // If we are in science mode, simply append results and break 
      if(device_mode == 'S') {
        // Append acceleration and angle rate information to the result vector
        for(int i = 0; i < 3; i++) {
          result.push_back((float_t) accel[i]); 
          result.push_back((float_t) angrate[i]); 
        }

        break; 
      }

      // If we do not want to output values, simply break
      if(!verbose) {
        break; 
      }

      Serial.print("X : ");Serial.println(accel[0]);
      Serial.print("Y : ");Serial.println(accel[1]);
      Serial.print("Z : ");Serial.println(accel[2]);
      Serial.print("AngRateX[mdps] : ");Serial.println(angrate[0]);
      Serial.print("AngRateY[mdps] : ");Serial.println(angrate[1]);
      Serial.print("AngRateZ[mdps] : ");Serial.println(angrate[2]);

      // Append End of Message terminator
      Serial.println("!");
      break; 
    
    // Read the temperature from the accelerometer
    case 'T':
      // If there was a problem with reading the temperature, throw an error 
      if(lsm6dsv16x->Get_Temp_Raw(&temperature) == LSM6DSV16X_ERROR) {
        sig_error();
        break; 
      }
      // If we are in science mode, simply append results 
      // and break
      if(device_mode == 'S') {
        // Append the temperature to the result vector 
        result.push_back((float_t) temperature);
        break; 
      }

      // Print out the temperature reading (C)
      Serial.println(temperature);

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

// Read from the SEEED XIAO BLE Sense nrf board
void SE_read(char mode, NRF_FICR_Type* board_info_reg) {
  // Initialie buffer for device id
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

// Write to the AS chip with a given mode and value to write
void AS_write(char mode, Adafruit_AS7341* as7341, char* write_val) {
  // Initialize integer representation of write_val
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

// Write to the TS chip in a given mode and with a given value to write
void TS_write(char mode, Adafruit_TSL2591* tsl2591, char* write_val) {
  // Initialize integer representation of write val
  uint16_t write_val_converted; 

  // Initialize set of valid gain choices
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

