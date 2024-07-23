#include "Arduino.h"
#include "Arduino_BuiltIn.h"
#include <Adafruit_AS7341.h>
#include <Adafruit_TSL2591.h>
#include <LIS2DUXS12Sensor.h>
#include <nrf.h>
#include <HardwareBLESerial.h>
#include <vector>

// Read a command from the serial input and populate 
// input buffer
void read_command(String* serial_input);

// Read a command from the BLE input and populate 
// and input buffer
void read_BLE_command(String* ble_input, HardwareBLESerial* bleSerial);

// Write information over BLE back to the caller 
void write_ble(HardwareBLESerial* bleSerial,
               std::vector<uint16_t>* AS_channels,
               std::vector<uint16_t>* TS_channels,
               std::vector<int32_t>* LI_channels,
               float_t LI_temp);

// Sends an error signal by writing -1 from the Serial port
void sig_error();

// Read various information (as specified by input) from the ASM7341 chip
std::vector<uint16_t> AS_read(char mode, Adafruit_AS7341* as7341);

// Read various information (as specified by input) from the TSL2591 chip
std::vector<uint16_t> TS_read(char mode, Adafruit_TSL2591* tsl2591);

// Read various information (as specified by input) from the LIS2DUXS12 chip
std::vector<int32_t> LI_read(char mode, LIS2DUXS12Sensor* lis2duxs12);

// Read various information (as specified by input) from the SEEED XIAO BLE Sense 
void SE_read(char mode, NRF_FICR_Type* board_info_reg);

// Write various information (as specified by input) from the ASM7341 chip
void AS_write(char mode, Adafruit_AS7341* as7341, char* write_val);

// Write various information (as specified by input) from the TSL2591 chip
void TS_write(char mode, Adafruit_TSL2591* tsl2591, char* write_val);

// Write various information (as specified by input) from the LIS2DUXS12 chip
void LI_write(char mode, LIS2DUXS12Sensor* lis2duxs12, char* write_val);


