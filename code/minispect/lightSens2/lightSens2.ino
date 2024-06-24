#include <Arduino_BuiltIn.h>

/* TSL2591 Digital Light Sensor */
/* Dynamic Range: 600M:1 */
/* Maximum Lux: 88K */


#include <HardwareBLESerial.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_TSL2591.h>
#include <Adafruit_AS7341_personal.h>
#include <LIS2DUXS12Sensor.h>
#include <Arduino.h>
#include <minispect_io.h>


HardwareBLESerial &bleSerial = HardwareBLESerial::getInstance();
Adafruit_TSL2591 tsl = Adafruit_TSL2591(2591);  // pass in a number for the sensor identifier (for your use later)
Adafruit_AS7341 as7341;
LIS2DUXS12Sensor LIS2DUXS12(&Wire);
int batSensPin = PIN_VBAT;         //PIN_VBAT
int readbatPin = PIN_VBAT_ENABLE;  //p14; //P0_14;//VBAT_ENABLE; //P0_14;// PIN_VBAT;   //PIN_VBAT

int32_t accel[3];
int16_t accel16[3];
uint16_t TSL2591_full;
uint16_t TSL2591_ir;
float TSL2591_lux;
uint16_t AS7341Data[10];
#define INTERVAL 2000  //ms
unsigned long lastRead = 0;
uint16_t VBat100x = 0;
// data array to BLE
// bytes 0-1 :D
// bytes 2-3 accel_x
// bytes 4-5 accel_y
// bytes 6-7 accel_z
// bytes 8-9 temp
// TSL2591
// bytes 10-11 FULL
// bytes 12-13 IR
// bytes 14-17 LUX
// AS7341
// bytes 18-19 ADC0/F1 415nm
// bytes 20-21 ADC1/F2 445nm
// bytes 22-23 ADC2/F3 480nm
// bytes 24-25 ADC3/F4 515nm
// bytes 26-27 ADC0/F5 555nm
// bytes 28-29 ADC1/F6 590nm
// bytes 30-31 ADC2/F7 630nm
// bytes 32-33 ADC3/F8 680nm
// bytes 34-35 ADC4/Clear
// bytes 36-37 ADC5/NIR
uint8_t dataBLE[40];
String serial_input = "";

char dtm[32];
String commandfz = "";
int astep = 259; //599 //399; //599;//999;
int atime = 249;   // 24; //29;   //49;
int gain = 5;     //4 //8;  //

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
  if (!bleSerial.beginAndSetupBLE("LightSense")) {
    while (true) {
      Serial.println("failed to initialize HardwareBLESerial!");
      delay(1000);
    }
  }



  dataBLE[0] = ':';
  dataBLE[1] = 'D';
  dataBLE[39] = '\n';
  Serial.println("HardwareBLESerial initialized!");

  // wait for a central device to connect
  //   while (!bleSerial);
  //   Serial.println("HardwareBLESerial central device connected!");
  TSL2591_init();
  AS7341_Reinit();
  LIS2DUXS12_init();
  Wire.setClock(400000);
  lastRead = millis();
  delay(1000);
}

void loop() {

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

      AS_read(serial_input[2], &as7341);
    
    }
    // Read from the TSL chip using specific data to read
    else if(mode_and_chip == "RT") {
      Serial.println("Read TS mode");

      TS_read(serial_input[2], &tsl);
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

  delay(10000);

  // if there is input to read and that input was a read
  // if(Serial.available() > 0) {
  //   char input = Serial.read()
    
  //   switch(input) {
  //     case 'R':
  //       lastRead = millis();
  //       digitalWrite(LED_GREEN, LOW);
  //       //simpleRead();
  //       advancedRead();
  //       AS7341_read();
  //       LIS2DUXS12_read();
  //       BatteryRead();
  //       digitalWrite(LED_GREEN, HIGH);
  //       if (bleSerial) {
  //        sendBLEData();
  //       }
  //       Serial.println();

  //     case ''
       
  // }

  //    BLERead2();

  //   }

    
    
}



void BLERead2() {
  bleSerial.poll();

  while (bleSerial.availableLines() > 0) {
    digitalWrite(LED_BLUE, LOW);
    digitalWrite(LED_RED, LOW);
    Serial.print("BLE Rec: ");
    bleSerial.readLine(dtm, 32);
    // String testT = "as7341,49,999,8\n";
    // strcpy( dtm, testT.c_str());
    Serial.println(dtm);
    sscanf(dtm, "%s %d %d %d\n", &commandfz, &atime, &astep, &gain);
    Serial.println(gain);
    // if (commandfz.indexOf("as73") >= 0){
    // Serial.println(command);
    //Serial.println(atime);
    // Serial.println(astep);
    // Serial.println(gain);
    AS7341_Reinit();
    Serial.println("AS7341 updated");
    //  }
    delay(50);
    digitalWrite(LED_BLUE, HIGH);
    digitalWrite(LED_RED, HIGH);
  }
}



void processCMD(String str) {
  strcpy(dtm, str.c_str());
  //   sscanf( dtm, "%s,%d,%d,%d", &command, &atime, &astep, &gain);
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


// Code for TSL2591

/**************************************************************************/
/*
    Displays some basic information on this sensor from the unified
    sensor API sensor_t type (see Adafruit_Sensor for more information)
*/
/**************************************************************************/
void displaySensorDetails(void) {
  sensor_t sensor;
  tsl.getSensor(&sensor);
  Serial.println(F("------------------------------------"));
  Serial.print(F("Sensor:       "));
  Serial.println(sensor.name);
  Serial.print(F("Driver Ver:   "));
  Serial.println(sensor.version);
  Serial.print(F("Unique ID:    "));
  Serial.println(sensor.sensor_id);
  Serial.print(F("Max Value:    "));
  Serial.print(sensor.max_value);
  Serial.println(F(" lux"));
  Serial.print(F("Min Value:    "));
  Serial.print(sensor.min_value);
  Serial.println(F(" lux"));
  Serial.print(F("Resolution:   "));
  Serial.print(sensor.resolution, 4);
  Serial.println(F(" lux"));
  Serial.println(F("------------------------------------"));
  Serial.println(F(""));
  delay(500);
}

/**************************************************************************/
/*
    Configures the gain and integration time for the TSL2591
*/
/**************************************************************************/
void configureSensor(void) {
  // You can change the gain on the fly, to adapt to brighter/dimmer light situations
  tsl.setGain(TSL2591_GAIN_LOW);  // 1x gain (bright light)
                                  //tsl.setGain(TSL2591_GAIN_MED);      // 25x gain
                                  //tsl.setGain(TSL2591_GAIN_HIGH);   // 428x gain

  // Changing the integration time gives you a longer time over which to sense light
  // longer timelines are slower, but are good in very low light situtations!
  tsl.setTiming(TSL2591_INTEGRATIONTIME_100MS);  // shortest integration time (bright light)
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_200MS);
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_300MS);
  //tsl.setTiming(TSL2591_INTEGRATIONTIME_400MS);
  // tsl.setTiming(TSL2591_INTEGRATIONTIME_500MS);
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

  /* Display some basic information on this sensor */
  displaySensorDetails();

  /* Configure the sensor */
  configureSensor();
}


/**************************************************************************/
/*
    Shows how to perform a basic read on visible, full spectrum or
    infrared light (returns raw 16-bit ADC values)
*/
/**************************************************************************/
void simpleRead(void) {
  // Simple data read example. Just read the infrared, fullspecrtrum diode
  // or 'visible' (difference between the two) channels.
  // This can take 100-600 milliseconds! Uncomment whichever of the following you want to read
  uint16_t x = tsl.getLuminosity(TSL2591_VISIBLE);
  //uint16_t x = tsl.getLuminosity(TSL2591_FULLSPECTRUM);
  //uint16_t x = tsl.getLuminosity(TSL2591_INFRARED);

  Serial.print(F("[ "));
  Serial.print(millis());
  Serial.print(F(" ms ] "));
  Serial.print(F("Luminosity: "));
  Serial.println(x, DEC);
}

/**************************************************************************/
/*
    Show how to read IR and Full Spectrum at once and convert to lux
*/
/**************************************************************************/
void advancedRead(void) {
  // More advanced data read example. Read 32 bits with top 16 bits IR, bottom 16 bits full spectrum
  // That way you can do whatever math and comparisons you want!
  uint32_t lum = tsl.getFullLuminosity();
  uint16_t ir, full;
  ir = lum >> 16;
  full = lum & 0xFFFF;
  TSL2591_full = full;
  TSL2591_ir = ir;
  TSL2591_lux = tsl.calculateLux(full, ir);
  Serial.print(F("[ "));
  Serial.print(millis());
  Serial.print(F(" ms ] "));
  Serial.print(F("IR: "));
  Serial.print(ir);
  Serial.print(F("  "));
  Serial.print(F("Full: "));
  Serial.print(full);
  Serial.print(F("  "));
  Serial.print(F("Visible: "));
  Serial.print(full - ir);
  Serial.print(F("  "));
  //   Serial.print(F("Lux: ")); Serial.println(tsl.calculateLux(full, ir), 6);
  Serial.print(F("Lux: "));
  Serial.println(TSL2591_lux);
}

/**************************************************************************/
/*
    Performs a read using the Adafruit Unified Sensor API.
*/
/**************************************************************************/
void unifiedSensorAPIRead(void) {
  /* Get a new sensor event */
  sensors_event_t event;
  tsl.getEvent(&event);

  /* Display the results (light is measured in lux) */
  Serial.print(F("[ "));
  Serial.print(event.timestamp);
  Serial.print(F(" ms ] "));
  if ((event.light == 0) | (event.light > 4294966000.0) | (event.light < -4294966000.0)) {
    /* If event.light = 0 lux the sensor is probably saturated */
    /* and no reliable data could be generated! */
    /* if event.light is +/- 4294967040 there was a float over/underflow */
    Serial.println(F("Invalid data (adjust gain or timing)"));
  } else {
    Serial.print(event.light);
    Serial.println(F(" lux"));
  }
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

  if (!as7341.setAGC(3, 3, 2)) {
    Serial.println("Could not set AGC thresholds");
  }

  //if (!as7341.enable_AGC(2, 0, 1)) {
   // Serial.println("Could not enable AGC");
  //}
}

void AS7341_read() {
  uint16_t readings[12];

  if (!as7341.readAllChannels(readings)) {
    Serial.println("Error reading all channels!");
    return;
  }
  //   memcpy(&AS7341Data[0],&readings[0],2);
  //   memcpy(&AS7341Data[1],&readings[1],2);
  //   memcpy(&AS7341Data[2],&readings[2],2);
  //   memcpy(&AS7341Data[3],&readings[3],2);
  memcpy(&AS7341Data[0], &readings[0], 8);
  memcpy(&AS7341Data[4], &readings[6], 12);
  Serial.print("ADC0/F1 415nm : ");
  Serial.println(readings[0]);
  Serial.print("ADC1/F2 445nm : ");
  Serial.println(readings[1]);
  Serial.print("ADC2/F3 480nm : ");
  Serial.println(readings[2]);
  Serial.print("ADC3/F4 515nm : ");
  Serial.println(readings[3]);
  Serial.print("ADC0/F5 555nm : ");

  /* 
  // we skip the first set of duplicate clear/NIR readings
  Serial.print("ADC4/Clear-");
  Serial.println(readings[4]);
  Serial.print("ADC5/NIR-");
  Serial.println(readings[5]);
  */

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

  Serial.print("Integration Time (ms): ");
  //Serial.println(integration_time);

  Serial.print("GAIN: ");
  Serial.println(as7341.getGain());
}

//Code for LIS2DUXS12
void LIS2DUXS12_init() {
  Wire.begin();
  LIS2DUXS12.begin();
  LIS2DUXS12.Enable_X();
}

void LIS2DUXS12_read() {
  LIS2DUXS12.Get_X_Axes(accel);
  accel16[0] = (uint16_t)accel[0];
  accel16[1] = (uint16_t)accel[1];
  accel16[2] = (uint16_t)accel[2];
  Serial.print("Accel-X[mg]:");
  Serial.print(accel[0]);
  Serial.print(",Accel-Y[mg]:");
  Serial.print(accel[1]);
  Serial.print(",Accel-Z[mg]:");
  Serial.println(accel[2]);
}

// Code for sendout BLE Data
void sendBLEData() {
  memcpy(&dataBLE[2], &accel16[0], 6);
  memcpy(&dataBLE[10], &TSL2591_full, 2);
  memcpy(&dataBLE[12], &TSL2591_ir, 2);
  memcpy(&dataBLE[14], &TSL2591_lux, 4);
  memcpy(&dataBLE[18], &AS7341Data[0], 20);
  for (int i = 0; i < 40; i++) {
    bleSerial.write(dataBLE[i]);
  }
  memcpy(&dataBLE[38], &VBat100x, 2);
  bleSerial.flush();
  memset(dataBLE, '\0', 40);
  dataBLE[0] = ':';
  dataBLE[1] = 'D';
  dataBLE[39] = '\n';
}