#include <Arduino_BuiltIn.h>
#include <HardwareBLESerial.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_TSL2591.h>
#include <Adafruit_AS7341.h>
#include <Arduino.h>
#include <LSM6DSV16XSensor.h>
#include <minispect_io.h>

// Initialize hardware connections
HardwareBLESerial &bleSerial = HardwareBLESerial::getInstance();
Adafruit_TSL2591 tsl2591 = Adafruit_TSL2591(2591); // user-defined sensor ID as parameter 
Adafruit_AS7341 as7341;

int vCtrl = D3;

LSM6DSV16XSensor LSM6DSV16X(&Wire);
#define INT1_pin D1
char report[256];
void INT1Event_cb();
void sendOrientation();

// Initialize parameters for AS7341 chip
int as_astep = 259;
int as_atime = 249;
int as_gain = 5;

// Initial parameters for TSL2591 chip 
auto tsl_gain = TSL2591_GAIN_HIGH;
auto tsl_integration_time = TSL2591_INTEGRATIONTIME_500MS; 

// Initialize buffers for the LSM6DSV16X chip
size_t buffer_size = 3 * 10;
std::vector<int16_t> accel_buffer;
std::vector<int16_t> angrate_buffer;
size_t accel_buffer_pos = 0;

// Initialize a container for input over the serial port
String serial_input = "";

// Store the current mode state of the device
char device_mode = 'S';

void setup() {
  accel_buffer.reserve(buffer_size);
  angrate_buffer.reserve(buffer_size);

  // Begin communicating at n baud 
  Serial.begin(115200);

  // Wait for the serial connection to be open
  while (!Serial);
  
  // Set relevant pins
  pinMode(vCtrl, OUTPUT);
  digitalWrite(vCtrl, LOW);
  
  // initialise ADC wireing_analog_nRF52.c:73
  analogReference(AR_INTERNAL2V4);        // default 0.6V*6=3.6V  wireing_analog_nRF52.c:73
  analogReadResolution(12);           // wireing_analog_nRF52.c:39

  // Initialize the sensors
  Serial.println("Initializing sensors..."); 
  
  BLE_init();
  AS7341_init();
  TSL2591_init();
  LSM6DSV16X_init();

  Serial.println("Sensors initialized");

  // Startup complete, add a small delay for hardware initialization to definitely 
  // complete
  delay(1000);
}

void loop() {
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
      return; 
    }
  }

  // Getting accelerometer data is highest priority, so 
  // read regardless of mode/command
  std::vector<float_t> LS_channels = LS_read('A', &LSM6DSV16X, device_mode, false); 
  
  // Then save the readings to the buffer
  for(size_t i = 0; i < LS_channels.size(); i+=2) {
    int16_t accel_value = (int16_t) LS_channels[i];
    int16_t angrate_value = (int16_t) LS_channels[i+1];
    size_t coord_number = i >> 1;  // counting by 2s, so a division by 2 will tell us the coordinate number

    // First, append to the acceleration buffer to the current buffer position + the number 
    // of coordinate we are on (X, Y, Z)
    accel_buffer.push_back(accel_value); 

    // Then append to the angle rate buffer 
    angrate_buffer.push_back(angrate_value); 
  }

  // 3 values were just added to each of the buffers, so increment the position 
  accel_buffer_pos += (LS_channels.size() / 2); 

  // If we are in fast science mode and the buffer is not full
  // simply incremement acceleration buffer and move to the next loop iteration
  if(device_mode == 'S' && accel_buffer_pos != buffer_size) {
    return; 
  }

  // If we are in science mode, focus only on building and sending the data buffer
  // when the accel buffer is full
  else if(device_mode == 'S' && accel_buffer_pos == buffer_size) {
      // Retrieve all 11 AS channels
      std::vector<uint16_t> AS_channels = AS_read('C',&as7341, device_mode);

      // Flicker is a very slow operation, discard
      //std::vector<uint16_t> AS_flicker = AS_read('F', &as7341, device_mode); 
      //AS_channels.push_back(AS_flicker[0]);
  
      // Retrieve 2 TS channels 
      std::vector<uint16_t> TS_channels = TS_read('C', &tsl2591, device_mode);

      // Retrieve the temp channel of the LI chip
      std::vector<float_t> LS_temp = LS_read('T', &LSM6DSV16X, device_mode, false); 

      // Write the data through the serial port 
      write_serial(&AS_channels, &TS_channels, &accel_buffer, &angrate_buffer, LS_temp[0]);  

      // Clear the buffers
      accel_buffer_pos = 0;
      accel_buffer.clear();
      angrate_buffer.clear();

      // Go to the next loop iteration
      return; 
  }

  // Otherwise we are in calibration mode
  if(accel_buffer_pos == buffer_size) {
    accel_buffer.clear();
    angrate_buffer.clear();
  }

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

    // Read from the LS chip using specific data to read
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

void TSL2591_init() {
  // Ensure the sensor can be found
  if(!tsl2591.begin()) {
    while(true) { Serial.println("Could not find TSL2591"); delay(1);}
  }

  // Set the initial parameters
  tsl2591.setGain(tsl_gain);
  tsl2591.setTiming(tsl_integration_time);

  Serial.println("TSL2591 Initialized!");
}

// Initialize the AS7341 Sensor
void AS7341_init() {
  // Ensure the sensor can be found
  if (!as7341.begin()) { 
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
  if (LSM6DSV16X.begin() == LSM6DSV16X_ERROR) {
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

// Initialize BLE communication
void BLE_init() {
    // Setup bluetooth emission
  if (!bleSerial.beginAndSetupBLE("White MS")) {
    while(true) {Serial.println("failed to initialize HardwareBLESerial!"); delay(1); }
  }

  Serial.println("BLE Initialized!");

}
