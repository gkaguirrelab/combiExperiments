#include <Arduino_BuiltIn.h>

/* TSL2591 Digital Light Sensor */
/* Dynamic Range: 600M:1 */
/* Maximum Lux: 88K */


#include <HardwareBLESerial.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_TSL2591.h>
#include <Adafruit_AS7341.h>
#include <LIS2DUXS12Sensor.h>
#include <Arduino.h>
#include <minispect_io.h>
#include <nrf.h>
#include <vector>
#include <bitset>

// Initialize hardware connections
HardwareBLESerial &bleSerial = HardwareBLESerial::getInstance();
Adafruit_TSL2591 tsl = Adafruit_TSL2591(2591);  // pass in a number for the sensor identifier (for your use later)
Adafruit_AS7341 as7341;
LIS2DUXS12Sensor LIS2DUXS12(&Wire);



int batSensPin = PIN_VBAT;         //PIN_VBAT
int readbatPin = PIN_VBAT_ENABLE;  //p14; //P0_14;//VBAT_ENABLE; //P0_14;// PIN_VBAT;   //PIN_VBAT

uint16_t VBat100x = 0;

// bytes 36-37 ADC5/NIR
String serial_input = "";
char device_mode = 'S';

String commandfz = "";
int astep = 259; //599 //399; //599;//999;
int atime = 249;   // 24; //29;   //49;
int gain = 5;     //4 //8;  //
int16_t accel_buffer[3 * 20];
int accel_buffer_pos = 0; 

void setup() {
  Serial.begin(115200);


  //while (!Serial);
  pinMode(LED_GREEN, OUTPUT);
  digitalWrite(LED_GREEN, HIGH);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_BLUE, HIGH);
  pinMode(batSensPin, INPUT);
  pinMode(readbatPin, OUTPUT);
  digitalWrite(readbatPin, LOW);
  
  // initialise ADC wireing_analog_nRF52.c:73
  analogReference(AR_INTERNAL2V4);  // default 0.6V*6=3.6V  wireing_analog_nRF52.c:73
  analogReadResolution(12);         // wireing_analog_nRF52.c:39


  if (!bleSerial.beginAndSetupBLE("White MS")) {
    while (true) {
      Serial.println("failed to initialize HardwareBLESerial!");
      delay(1000);
    }
  }

  Serial.println("HardwareBLESerial initialized!");
  TSL2591_init();
  AS7341_Reinit();
  LIS2DUXS12_init();
  Wire.setClock(400000);
  delay(1000);
}

void loop() {

  // Getting accelerometer data is highest priority, so
  // first perform read 
  std::vector<float_t> LI_channels = LI_read('A', &LIS2DUXS12, device_mode); 
  
  // Then save the readings to the buffer
  for(size_t i = 0; i < LI_channels.size(); i++) {
    accel_buffer[accel_buffer_pos+i] = (int16_t)LI_channels[i]; 
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
      std::vector<uint16_t> TS_channels = TS_read('C',&tsl, device_mode);

      // Retrieve the temp channel of the LI chip
      std::vector<float_t> LI_temp = LI_read('T', &LIS2DUXS12, device_mode); 

      // Write the data through the serial port 
      write_serial(&AS_channels, &TS_channels, LI_temp[0], accel_buffer, 60);  

      // Increment buffer position, reset if necessary
      accel_buffer_pos = (accel_buffer_pos + 3) % 60; 

      // Go to the next loop iteration
      return; 
  }

  // Increment buffer position, reset if necessary
  accel_buffer_pos = (accel_buffer_pos + 3) % 60; 

  // Otherwise, we are in calibration mode, so we can read/send commands

  // Get the command from the controller
  read_command(&serial_input); 

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

      TS_read(serial_input[2], &tsl, device_mode);
    }

    // Read from the SEEED chip using specific data to read
    else if(mode_and_chip == "RS") {
      Serial.println("Read SE mode");

      SE_read(serial_input[2], NRF_FICR);
    }

    // Read from the LI chip using specific data to read
    else if(mode_and_chip == "RL") {
      LI_read(serial_input[2],&LIS2DUXS12, device_mode);
    }

    // Write to the AS chip using given data
    else if(mode_and_chip == "WA") {
      Serial.println("Write AS mode");

      AS_write(serial_input[2], &as7341, &serial_input[3]);

    }

    // Write to the TSL chip using given data
    else if(mode_and_chip == "WT") {
      Serial.println("Write TS mode"); 

      TS_write(serial_input[2], &tsl, &serial_input[3]);
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
void BLESerial_func() {
  // this must be called regularly to perform BLE updates
  bleSerial.poll();

  // whatever is written to BLE UART appears in the Serial Monitor
  while (bleSerial.available() > 0) {
    Serial.write(bleSerial.read());
  }

  // whatever is written in Serial Monitor appears in BLE UART
  while (Serial.available() > 0) {
    bleSerial.write(Serial.read());
  }
}





/**************************************************************************/
/*
    Configures the gain and integration time for the TSL2591
*/
/**************************************************************************/
void configureSensor(void) {
  // You can change the gain on the fly, to adapt to brighter/dimmer light situations
  tsl.setGain(TSL2591_GAIN_HIGH);  // 1x gain (bright light)
                                  //tsl.setGain(TSL2591_GAIN_MED);      // 25x gain
                                  //tsl.setGain(TSL2591_GAIN_HIGH);   // 428x gain

  // Changing the integration time gives you a longer time over which to sense light
  // longer timelines are slower, but are good in very low light situtations!
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_100MS);  // shortest integration time (bright light)
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_200MS);
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_300MS);
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_400MS);
  tsl.setTiming(TSL2591_INTEGRATIONTIME_500MS);
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_600MS);  // longest integration time (dim light)

  /* Display the gain and integration time for reference sake */
  Serial.println(F("------------------------------------"));
  Serial.print(F("Gain:         "));
  tsl2591Gain_t gain = tsl.getGain();
  switch (gain) {
    case TSL2591_GAIN_LOW:
      Serial.println(F("1x (Low)"));
      break;
    case TSL2591_GAIN_MED:
      Serial.println(F("25x (Medium)"));
      break;
    case TSL2591_GAIN_HIGH:
      Serial.println(F("428x (High)"));
      break;
    case TSL2591_GAIN_MAX:
      Serial.println(F("9876x (Max)"));
      break;
  }
  Serial.print(F("Timing:       "));
  Serial.print((tsl.getTiming() + 1) * 100, DEC);
  Serial.println(F(" ms"));
  Serial.println(F("------------------------------------"));
  Serial.println(F(""));
}

void TSL2591_init() {
  if (tsl.begin()) {
    Serial.println(F("Found a TSL2591 sensor"));
    digitalWrite(LED_GREEN, LOW);
    Serial.flush();
    delay(500);
  } else {
    Serial.println(F("No sensor found ... check your wiring?"));
    // digitalWrite(LED_RED, LOW);
    Serial.flush();
    delay(500);
    while (1)
      ;
  }

  /* Configure the sensor */
  configureSensor();
}

// Code for AS7341
void AS7341_init() {
  if (!as7341.begin()) {
    Serial.println("Could not find AS7341");
    while (1) { delay(10); }
  }
  //(ATIME + 1) * (ASTEP + 1) * 2.78µS
  as7341.setATIME(49);
  as7341.setASTEP(999);
  as7341.setGain(AS7341_GAIN_128X);  //AS7341_GAIN_256X
}

void AS7341_Reinit() {
  if (!as7341.begin()) {
    Serial.println("Could not find AS7341");
    while (1) { delay(10); }
  }
  //(ATIME + 1) * (ASTEP + 1) * 2.78µS
  as7341.setATIME(uint8_t(atime));
  as7341.setASTEP(uint16_t(astep));
  as7341.setGain(as7341_gain_t(gain));  //AS7341_GAIN_256X

}

//Code for LIS2DUXS12
void LIS2DUXS12_init() {
  Wire.begin();
  LIS2DUXS12.begin();
  LIS2DUXS12.Enable_X();
}