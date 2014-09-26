#include <TinyGPS++.h>
#include <SoftwareSerial.h>
#include <EEPROM.h>
/*
   This program for Surinrobot Point build 10
*/
static const int RXPin = 2, TXPin = 3,gsmRXPin = 4, gsmTXPin = 5,SIM900SWITCH = 7,SIM900STATUS = 6 ,linkLED = 13;
static const uint32_t GPSBaud = 9600;
int GPS_Error_Count = 0; // Count Time not Accquire GPS
static const int build = 10;
String Device_id;
String lati;
String lon;
String speeds;

// The TinyGPS++ object
TinyGPSPlus gps;

// The serial connection to the GPS device
SoftwareSerial myGSM(gsmRXPin, gsmTXPin);
SoftwareSerial ss(RXPin, TXPin);


void setup()
{
  Serial.begin(115200);
  ss.begin(GPSBaud);
  myGSM.begin(GPSBaud);
  
  pinMode(SIM900STATUS, INPUT);
  pinMode(SIM900SWITCH, OUTPUT);

  pinMode(linkLED, OUTPUT);
  Serial.println("Start loop");
  digitalWrite(SIM900SWITCH, LOW);
  delay(3000);
  digitalWrite(SIM900SWITCH, HIGH);
  
  InnitSim900();
}

void loop()
{
    boolean feedResult = getGPS();
    digitalWrite(linkLED, HIGH);
    if(!feedResult)
      softReset();
    
    while(sendATcommand("AT+HTTPINIT", "OK", 3000)==0);
    Serial.println("resister APN"); 
    
    while(sendATcommand("AT+HTTPPARA=\"CID\",1", "OK", 3000)==0);
    Serial.println("GPRS IP pass");
    
     myGSM.print("AT+HTTPPARA=\"URL\",\"http://www.surinrobot.com/point/serverside/point_avr_post.php?lat=");
    delay(250);
    myGSM.print(gps.location.lat());
    delay(250);
    myGSM.print("&lon=");
    delay(250);
    myGSM.print(gps.location.lng());
    delay(250);
     myGSM.print("&device_id=a2-114");
    delay(250);
    //myGSM.print(Device_id);
    //delay(250);
     myGSM.print("&b=");
    delay(250);
     myGSM.print(build);
     delay(250);
         myGSM.print("&speed=");
    delay(250);
    myGSM.print(gps.speed.kmph());
    delay(250);
     myGSM.println(" HTTP/1.1");
      delay(250);
       myGSM.println("\""); 
      digitalWrite(linkLED,LOW);
      
    
    myGSM.println("AT+HTTPACTION=0");
    delay(2500);
    Serial.println("return Head");
    
    myGSM.println("AT+HTTPREAD");
    Serial.println("return Head");
      
    printInt(gps.satellites.value(), gps.satellites.isValid(), 5);
    printInt(gps.hdop.value(), gps.hdop.isValid(), 5);
    printFloat(gps.location.lat(), gps.location.isValid(), 11, 6);
    printFloat(gps.location.lng(), gps.location.isValid(), 12, 6);
    printDateTime(gps.date, gps.time);
    printFloat(gps.altitude.meters(), gps.altitude.isValid(), 7, 2);
    printFloat(gps.speed.kmph(), gps.speed.isValid(), 6, 2);
 
    Serial.println();
    delay(10000);
}
/*
  Reset AVR
*/
void softReset(){
  asm volatile ("  jmp 0");
}

void power_on(){

    uint8_t answer=0;
    
    // checks if the module is started
    answer = sendATcommand("AT", "OK", 2000);
    Serial.print("AT res = ");
    Serial.println(answer);
    if (answer == 0)
    {
        // power on pulse
        digitalWrite(SIM900SWITCH,LOW);
        delay(3000);
        digitalWrite(SIM900SWITCH,HIGH);
    
        // waits for an answer from the module
        while(answer == 0){     // Send AT every two seconds and wait for the answer
            answer = sendATcommand("AT", "OK", 2000);    
        }
    }
    
    /*** Fix Baud rate to 9600 in order to eliminate possible errors 
         in detecting the serial speed rate
    ***/
    answer = sendATcommand("AT+IPR=9600", "OK", 2000);
    Serial.print("AT+IPR res = ");
    Serial.println(answer);
    
    /*** 
        check is the SIM presence and PIN code insertion
    ***/
    answer = sendATcommand("AT+CPIN?", "+CPIN: READY", 2000);
    Serial.print("AT+CPIN res = ");
    Serial.println(answer); 
    
    /*** 
        Enable verbose
    ***/
    answer = sendATcommand("AT+CMEE=1", "OK", 2000);
    Serial.print("AT+CMEE res = ");
    Serial.println(answer); 
    
    /*** 
        Rec as first ring
    ***/
    answer = sendATcommand("ATS0=1", "OK", 2000);
    Serial.print("ATS0 res = ");
    Serial.println(answer); 
    
    /***
        Set SMS as TEXT mode
    ***/
    answer = sendATcommand("AT+CMGF=1", "OK", 2000);
    Serial.print("SMS as text res = ");
    Serial.println(answer); 

}

void InnitSim900()
{
  device_id();
  delay(5000);
  
  Serial.println(Device_id);

  if (myGSM.available()){
       while(String(Serial.write(myGSM.read())) == "Call Ready");
      }

  Serial.println("Starting...");
    power_on();
    Serial.println("Connecting to the network...");
    /*
    int answer1 = sendATcommand("AT+CREG?", "+CREG: 1,5", 500);
        Serial.print("AT+CREG? = ");
    Serial.println(answer1);
    */
    while(sendATcommand("AT+CREG?", "+CREG: 1,1", 500) == 0);
  Serial.println("connected");

      /***
        Attach to GPRS network
        
        Chech for attach Network
        
        AT+CGATT?
        +CGATT:0
        OK
    ***/
    while(sendATcommand("AT+CGATT=1", "OK", 3000)==0);
    Serial.println("GPRS Attached");
    
    /***
        Attach to GPRS network
        
        Chech for attach Network
        
        AT+CGATT?
        +CGATT:0
        OK
    ***/
    while(sendATcommand("AT+COPS=?", "OK", 3000)==0);
    Serial.println("GPRS Attached");
    
    while(sendATcommand("AT+SAPBR=3,1,\"CONTYPE\",\"GPRS\"", "OK", 3000)==0);
    Serial.println("resister APN"); 

    while(sendATcommand("AT+SAPBR=3,1,\"APN\",\"www.dtac.co.th\"", "OK", 3000)==0);
    Serial.println("resister APN"); 
    
    while(sendATcommand("AT+SAPBR=1,1", "OK", 3000)==0);
    Serial.println("resister APN"); 
   
}


int8_t sendATcommand(char* ATcommand, char* expected_answer, unsigned int timeout){
    myGSM.listen();
    uint8_t x=0,  answer=0;
    char response[100];
    unsigned long previous;

    memset(response, '\0', 100);    // Initialize the string
    
    delay(100);
    
    while( myGSM.available() > 0) myGSM.read();    // Clean the input buffer
    
    myGSM.println(ATcommand);    // Send the AT command 

    x = 0;
    previous = millis();

    // this loop waits for the answer
    do{
        // if there are data in the UART input buffer, reads it and checks for the asnwer
        if(myGSM.available() != 0){    
            response[x] = myGSM.read();
            x++;
            Serial.println(response);
            // check if the desired answer  is in the response of the module
            if (strstr(response, expected_answer) != NULL)    
            {
                answer = 1;
            }
            
        }
        // Waits for the asnwer with time out
    }while((answer == 0) && ((millis() - previous) < timeout));    

    return answer;
}

void device_id()//read device id from eeprom
{ 
  for(int k = 0;k<6;k++) 
  {
    Device_id = String(Serial.write(EEPROM.read(k)));
  }
}

boolean getGPS()
{
  while(!gps.location.isValid())
  {
    smartDelay(1000);
    if(gps.location.isValid())
    {
      return true;
      break;
    }
    
    if(GPS_Error_Count == 300)
    {
      return false;
      break; 
    }
    
    GPS_Error_Count++;
    if (millis() > 5000 && gps.charsProcessed() < 10)
      Serial.println(F("No GPS data received: check wiring"));
  }
}
// This custom version of delay() ensures that the gps object
// is being "fed".
static void smartDelay(unsigned long ms)
{
  ss.listen();
  unsigned long start = millis();
  do 
  {
    while (ss.available())
      gps.encode(ss.read());
  } while (millis() - start < ms);
}

static void printFloat(float val, bool valid, int len, int prec)
{
  if (!valid)
  {
    while (len-- > 1)
      Serial.print('*');
    Serial.print(' ');
  }
  else
  {
    Serial.print(val, prec);
    int vi = abs((int)val);
    int flen = prec + (val < 0.0 ? 2 : 1); // . and -
    flen += vi >= 1000 ? 4 : vi >= 100 ? 3 : vi >= 10 ? 2 : 1;
    for (int i=flen; i<len; ++i)
      Serial.print(' ');
  }
  smartDelay(0);
}

static void printInt(unsigned long val, bool valid, int len)
{
  char sz[32] = "*****************";
  if (valid)
    sprintf(sz, "%ld", val);
  sz[len] = 0;
  for (int i=strlen(sz); i<len; ++i)
    sz[i] = ' ';
  if (len > 0) 
    sz[len-1] = ' ';
  Serial.print(sz);
  smartDelay(0);
}

static void printDateTime(TinyGPSDate &d, TinyGPSTime &t)
{
  if (!d.isValid())
  {
    Serial.print(F("********** "));
  }
  else
  {
    char sz[32];
    sprintf(sz, "%02d/%02d/%02d ", d.month(), d.day(), d.year());
    Serial.print(sz);
  }
  
  if (!t.isValid())
  {
    Serial.print(F("******** "));
  }
  else
  {
    char sz[32];
    sprintf(sz, "%02d:%02d:%02d ", t.hour(), t.minute(), t.second());
    Serial.print(sz);
  }

  printInt(d.age(), d.isValid(), 5);
  smartDelay(0);
}
