#include "TinyGPS++.h"
#include <SoftwareSerial.h>
#include <EEPROM.h>

#define build           10  //เปลี่ยนตาม build ที่ได้แก้ไข
#define SIM900SWITCH     7    //IO pin to switch GPRS on/off
#define SIM900STATUS     6    //IO pin to check if powered on
#define linkLED         13
#define SIMSIZE          3   //total storage space on SIM card
#define gsmRx            4   // Rx to Sim900
#define gsmTx            5   // Tx to Sim900
#define gpsRx            2   // Rx to GPS
#define gpsTx            3   // Tx to GPS

String Device_id;
TinyGPSPlus gps;

SoftwareSerial myGPS =  SoftwareSerial(gpsRx, gpsTx);

void setup()
{
  Serial.begin(115200);
  myGPS.begin(9600);
  pinMode(gpsRx, INPUT);
  pinMode(gpsTx, OUTPUT);
  pinMode(gsmRx, INPUT);
  pinMode(gsmTx, OUTPUT);
  
  pinMode(SIM900STATUS, INPUT);
  pinMode(SIM900SWITCH, OUTPUT);

  pinMode(linkLED, OUTPUT);
  
  digitalWrite(SIM900SWITCH, HIGH);
  digitalWrite(linkLED, HIGH);
  
  device_id();
  delay(500);
  Serial.println(Device_id);
}

void loop()
{
  getGPDS();
  delay(3000);
}

void getGPS()
{
    digitalWrite(linkLED, HIGH);
  while (myGPS.available() > 0)
    gps.encode(myGPS.read());
    digitalWrite(linkLED, LOW);
    if (gps.location.isUpdated())
  {
    Serial.print("LAT="); Serial.print(gps.location.lat(), 6);
    Serial.print("LNG="); Serial.println(gps.location.lng(), 6);
    Serial.print("Speed=");Serial.println(gps.speed.kmph());
  }
}

void device_id()//read device id from eeprom
{ 
  for(int k = 0;k<6;k++) 
  {
    Device_id = String(Serial.write(EEPROM.read(k)));
  }
}
