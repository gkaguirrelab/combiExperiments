#include <Arduino_BuiltIn.h>
#include <HardwareBLESerial.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_TSL2591.h>
#include <Adafruit_AS7341.h>
#include <Arduino.h>
#include <minispect_io.h>
#include <nrf.h>
#include <vector>
#include <bitset>
#include <LSM6DSV16XSensor.h>

// Initialize hardware connections
HardwareBLESerial &bleSerial = HardwareBLESerial::getInstance();
Adafruit_TSL2591 tsl2591 = Adafruit_TSL2591(2591);  // pass in a number for the sensor identifier (for your use later)
Adafruit_AS7341 as7341;
LSM6DSV16XSensor LSM6DSV16X(&Wire);
int batSensPin = PIN_VBAT;         //PIN_VBAT
int readbatPin = PIN_VBAT_ENABLE;  //p14; //P0_14;//VBAT_ENABLE; //P0_14;// PIN_VBAT;   //PIN_VBAT
uint16_t VBat100x = 0;

// Initialize input buffer
String serial_input = "";

// Set device mode
char device_mode = 'S';

// Initialize parameters for AS7341 chip
int as_astep = 259;
int as_atime = 249;
int as_gain = 5;

// Initial parameters for TSL2591 chip 
auto tsl_gain = TSL2591_GAIN_HIGH;
auto tsl_integration_time = TSL2591_INTEGRATIONTIME_500MS; 

// Initialize the accelerometer value buffer 
// and the next open index in it
int16_t accel_buffer[3 * 20];
int accel_buffer_pos = 0; 

// Initial setup 
void setup() {
  // Begin communication at 115200 baudrate
  Serial.begin(115200);

  Serial.println("Initializing sensors...");
  
  // initialise ADC wireing_analog_nRF52.c:73
  analogReference(AR_INTERNAL2V4);  // default 0.6V*6=3.6V  wireing_analog_nRF52.c:73
  analogReadResolution(12);         // wireing_analog_nRF52.c:39

  // Initialize sensors
  Serial.println("Attempting to initialize bluetooth...");
  BLE_init();
  
  Serial.println("Attempting to initialize TSL2591...");
  TSL2591_init();

  Serial.println("Attempting to initialize AS7341...");
  AS7341_init();

  Serial.println("Attempting to initialize LSM6DSV16X...");
  LSM6DSV16X_init();

  // Allow time for everything to set up
  delay(1000);
}

void loop() {
  return ; 

  // Get the command from the controller
  read_command(&serial_input); 
  
  // Quickly check to see if we are changing modes (needs to be >= 3 instead of == 3 to conform with 
  // the MATLAB write_minispect interface, as it adds an extra character even if passed '')
  if(serial_input.length() >= 3) {
    // Get the mode to perform and the chip to do it on
    String mode_and_chip = serial_input.substring(0,2); 

    // Change the device mode (e.g, from science to calibration)
    if(mode_and_chip == "WM") {
      Serial.println("Change device mode");
      device_mode = serial_input[2]; 
      
      Serial.println(device_mode); 
      Serial.println("!"); 

      serial_input = "";
      return ; 
    }
  }


  // Getting accelerometer data is highest priority, so 
  // read regardless of mode/command
  std::vector<float_t> LS_channels = LS_read('A', &LSM6DSV16X, device_mode, false); 
  
  // Then save the readings to the buffer
  for(size_t i = 0; i < LS_channels.size(); i++) {
    accel_buffer[accel_buffer_pos+i] = (int16_t) LS_channels[i]; 
  }

  // If we are in fast science mode and the buffer is not full
  // simply incremement acceleration buffer and move to the next loop iteration
  if(device_mode == 'S' && accel_buffer_pos != 57) {
    
    // Increment buffer position, reset if necessary
    accel_buffer_pos = (accel_buffer_pos + 3) % 60; 

    return ; 
  }

  // If we are in science mode, focus only on building and sending the data buffer
  // when the accel buffer is full
  else if(device_mode == 'S' && accel_buffer_pos == 57) {
      // Retrieve all 11 AS channels
      std::vector<uint16_t> AS_channels = AS_read('C',&as7341, device_mode);

      // Flicker is a very slow operation, discard
      //std::vector<uint16_t> AS_flicker = AS_read('F', &as7341, device_mode); 
      //AS_channels.push_back(AS_flicker[0]);
  
      // Retrieve 2 TS channels 
      std::vector<uint16_t> TS_channels = TS_read('C',&tsl2591, device_mode);

      // Retrieve the temp channel of the LI chip
      std::vector<float_t> LS_temp = LS_read('T', &LSM6DSV16X, device_mode, false); 

      // Write the data through the serial port 
      write_serial(&AS_channels, &TS_channels, LS_temp[0], accel_buffer, 60);  

      // Increment buffer position, reset if necessary
      accel_buffer_pos = (accel_buffer_pos + 3) % 60; 

      // Go to the next loop iteration
      return; 
  }

  // Increment buffer position, reset if necessary
  accel_buffer_pos = (accel_buffer_pos + 3) % 60; 

  // Otherwise, we are in calibration mode, so we can read/write to specific chips

  // If we received a well formed command, execute it
  if(serial_input.length() > 2) {
    Serial.println(serial_input);
    
    // Get the mode to perform and the chip to do it on
    String mode_and_chip = serial_input.substring(0,2); 

    // Read from the AS chip using given specific data to read
    if(mode_and_chip == "RA") {
      Serial.println("Read AS mode"); 

      AS_read(serial_input[2], &as7341, device_mode);
    
    }
    // Read from the TSL chip using specific data to read
    else if(mode_and_chip == "RT") {
      Serial.println("Read TS mode");

      TS_read(serial_input[2], &tsl2591, device_mode);
    }

    // Read from the SEEED chip using specific data to read
    else if(mode_and_chip == "RS") {
      Serial.println("Read SE mode");

      SE_read(serial_input[2], NRF_FICR);
    }

    // Read from the LI chip using specific data to read
    else if(mode_and_chip == "RL") {
      LS_read(serial_input[2],&LSM6DSV16X, device_mode, true);
    }

    // Write to the AS chip using given data
    else if(mode_and_chip == "WA") {
      Serial.println("Write AS mode");

      AS_write(serial_input[2], &as7341, &serial_input[3]);

    }

    // Write to the TSL chip using given data
    else if(mode_and_chip == "WT") {
      Serial.println("Write TS mode"); 

      TS_write(serial_input[2], &tsl2591, &serial_input[3]);
    }   

    // Invalid command
    else {
      Serial.println("-1");
      Serial.println("!");
    }
  }
  // Reset command to empty after execution. 
  serial_input = "";

}

void BatteryRead() {
  int vbatt = analogRead(batSensPin);
  VBat100x = int((240 * vbatt / 4096) * 3.06849);
  Serial.print(vbatt, HEX);
  Serial.print("    ");
  Serial.print(2.40 * vbatt / 4096);  // Resistance ratio 2.961, Vref = 2.4V
  Serial.print("V    ");
  Serial.print((2.40 * vbatt / 4096) * 3.06849);  // Resistance ratio 2.96078, Vref = 2.4V
  Serial.println("V    ");
  //  Serial.println(digitalRead(PIN_CHG));
}

void TSL2591_init() {
  // Ensure the sensor can be found
  if(!tsl2591.begin()) {
    while(true) { Serial.println("Could not find TSL2591"); delay(1);}
  }

  // Set the initial parameters
  tsl2591.setGain(TSL2591_GAIN_HIGH);
  tsl2591.setTiming(TSL2591_INTEGRATIONTIME_500MS);

  Serial.println("TSL2591 Initialized!");
}

// Initialize the AS7341 Sensor
void AS7341_init() {
  // Ensure the sensor can be found
  if (!as7341.begin()) {
    Serial.println("Could not find AS7341");
    while(true) { Serial.println("Could not find AS7341"); delay(1);}
  }

  //Set the initial parameters
  as7341.setATIME(uint8_t(as_atime));
  as7341.setASTEP(uint16_t(as_astep));
  as7341.setGain(as7341_gain_t(as_gain));

  // Disable the Spectral AGC
  as7341.toggleAGC(false); 

  Serial.println("AS7341 Initialized!");
}

// Initialize the LSM6DSV16X sensor
void LSM6DSV16X_init() {
  // Ensure the sensor can be found
  if (LSM6DSV16X.begin()) {
    while(true) { Serial.println("Could not find LSM6DSV16X"); delay(1);}
  }

  LSM6DSV16X.Enable_X();
  LSM6DSV16X.Enable_G();

  uint8_t id = 0xFF;
  LSM6DSV16X.ReadID(&id);
  Serial.print("id "); Serial.println(id);
  Wire.setClock(400000);

  Serial.println("LSM6DSV16X Initialized!");

}

void BLE_init() {
    // Setup bluetooth emission
  if (!bleSerial.beginAndSetupBLE("White MS")) {
    while(true) {Serial.println("failed to initialize HardwareBLESerial!"); delay(1); }
  }

  Serial.println("BLE Initialized!");

}