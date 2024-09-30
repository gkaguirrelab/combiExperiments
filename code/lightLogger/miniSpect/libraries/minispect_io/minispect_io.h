#include "Arduino.h"
#include "Arduino_BuiltIn.h"
#include <Adafruit_AS7341.h>
#include <Adafruit_TSL2591.h>
#include <nrf.h>
#include <HardwareBLESerial.h>
#include <vector>
#include <LSM6DSV16XSensor.h>

// Read a command from the serial input and populate 
// input buffer
void read_command(String* serial_input);

// Read a command from the BLE input and populate 
// and input buffer
void read_BLE_command(String* ble_input, HardwareBLESerial* bleSerial);

// Write information over the serial port
void write_serial(std::vector<uint16_t>* AS_channels,
                  std::vector<uint16_t>* TS_channels,
                  float_t LS_temp,
                  int16_t* accel_buffer,
                  size_t buff_size);


// Write information over BLE back to the caller 
void write_ble(HardwareBLESerial* bleSerial,
               std::vector<uint16_t>* AS_channels,
               std::vector<uint16_t>* TS_channels,
               int16_t* accel_buffer,
               float_t LS_temp);

// Sends an error signal by writing -1 from the Serial port
void sig_error();

// Read various information (as specified by input) from the ASM7341 chip
std::vector<uint16_t> AS_read(char mode, Adafruit_AS7341* as7341, char device_mode);

// Read various information (as specified by input) from the TSL2591 chip
std::vector<uint16_t> TS_read(char mode, Adafruit_TSL2591* tsl2591, char device_mode);

// Read various information (as specified by input) from the #include LSM6DSV16X chip
std::vector<float_t> LS_read(char mode, LSM6DSV16XSensor* lsm6dsv16x, char device_mode, bool verbose);

// Read various information (as specified by input) from the SEEED XIAO BLE Sense 
void SE_read(char mode, NRF_FICR_Type* board_info_reg);

// Write various information (as specified by input) from the ASM7341 chip
void AS_write(char mode, Adafruit_AS7341* as7341, char* write_val);

// Write various information (as specified by input) from the TSL2591 chip
void TS_write(char mode, Adafruit_TSL2591* tsl2591, char* write_val);



