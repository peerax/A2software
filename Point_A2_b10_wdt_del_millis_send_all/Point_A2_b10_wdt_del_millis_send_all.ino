#include <TinyGPS++.h>
#include <SoftwareSerial.h>
#include <EEPROM.h>
#include <avr/wdt.h>
#include <avr/io.h>
#include <MemoryFree.h>
/*
   This program for Surinrobot Point build 10
*/
static const int RXPin = 2, TXPin = 3,gsmRXPin = 4, gsmTXPin = 5,SIM900SWITCH = 7,SIM900STATUS = 6 ,linkLED = 13;
static const uint32_t GPSBaud = 9600;
int GPS_Error_Count = 0; // Count Time not Accquire GPS
static const int build = 10;
String Device_id;

int GREG_Error = 0;
int Conn_Err = 0;
int Is_true = 0;
int Hour_Reset = 0;

// The TinyGPS++ object
TinyGPSPlus gps;

// The serial connection to the GPS device
SoftwareSerial myGSM(gsmRXPin, gsmTXPin);
SoftwareSerial ss(RXPin, TXPin);

void wdtSetup() {
 wdt_enable(WDTO_8S);
}
 
ISR(WDT_vect) // Watchdog Timer interrupt handler
{
  digitalWrite(linkLED, LOW);
  asm volatile ("  jmp 0");
}

void setup()
{
  Hour_Reset = 0;
  Conn_Err = 0;
  wdt_disable();
  wdtSetup();
  Serial.begin(115200);
  ss.begin(GPSBaud);
  myGSM.begin(GPSBaud);
  
  pinMode(SIM900STATUS, INPUT);
  pinMode(SIM900SWITCH, OUTPUT);
  
  wdt_reset();
  pinMode(linkLED, OUTPUT);
  digitalWrite(linkLED, LOW);
  
  Serial.println("Start loop");
  /*
  digitalWrite(SIM900SWITCH, LOW);
  delay(3000);
  digitalWrite(SIM900SWITCH, HIGH);
  */
  wdt_reset();
  
  InnitSim900();
}

void loop()
{
    wdt_reset();
    Hour_Reset ++;
    boolean feedResult = getGPS();
    wdt_reset();
    digitalWrite(linkLED, HIGH);
    if(!feedResult)
      {
                
         if(Conn_Err > 20)
            { softReset();};
        sendNullData();
        Conn_Err++;

    }else{
    //Conn_Err = 0;
    wdt_reset();
    
    while(sendATcommand("AT+CIPSTART=\"TCP\",\"www.surinrobot.com\",\"80\"", "ALREADY CONNEC", 2000) == 0)
    {
      wdt_reset();
     Conn_Err++;
      if(Conn_Err > 20)
        { softReset();};
    };
    Serial.println("connected ok");
    
    wdt_reset();
    myGSM.println("AT+CIPSEND");
    delay(250);
    myGSM.print("GET /point/serverside/point_avr_post.php?lat="); 
    Serial.print("GET /point/serverside/point_avr_post.php?lat=");
    delay(250);

    myGSM.print(gps.location.lat(),6);
    Serial.print(gps.location.lat(),6);
    delay(250);
    myGSM.print("&lon=");
    Serial.print("&lon=");
    delay(250);

    myGSM.print(gps.location.lng(),6);
    Serial.print(gps.location.lng(),6);
    delay(250);
     myGSM.print("&device_id=");
     Serial.print("&device_id=");
    delay(250);
    device_id();
    myGSM.print(Device_id);
    Serial.print(Device_id);
    delay(250);
  myGSM.print("&b=");
  Serial.print("&b=");
  delay(250);
  myGSM.print(build);
  Serial.print(build);
  delay(250);
  myGSM.print("&speed=");
  Serial.print("&speed=");
  delay(250);
  myGSM.print(gps.speed.kmph());
  Serial.print(gps.speed.kmph());
  delay(250);
  wdt_reset();
  myGSM.print(" HTTP/1.1\r\n");
  delay(500);
  myGSM.print("host:www.surinrobot.com\r\n");
  delay(250);
  wdt_reset();
  myGSM.print("Connection: Keep-Alive");         //working as well
  myGSM.print("\r\n");
  myGSM.print("\r\n");
  delay(250);
  wdt_reset();
  myGSM.write(0x1A);
  wdt_reset();
  delay(500);
  //myGSM.println();
  Serial.println("Complete");
      }
      
  wdt_reset();
  while(sendATcommand("AT+CIPSTATUS", "SEND OK", 2000) == 0)
      {
     Conn_Err++;
      break;
    };

  wdt_reset();
  while(sendATcommand("AT+CIPCLOSE", "CLOSE OK", 2000) == 0)
      {
     Conn_Err++;
      if(Conn_Err > 20)
        { softReset();};
    };
    
   if(Conn_Err > 15)
      { 
        softReset();
      };
    
   // Serial.print("freeMemory()=");
  //  Serial.println(freeMemory());
  
    
    digitalWrite(linkLED,LOW);
     /* 
    printInt(gps.satellites.value(), gps.satellites.isValid(), 5);
    printInt(gps.hdop.value(), gps.hdop.isValid(), 5);
    printFloat(gps.location.lat(), gps.location.isValid(), 11, 6);
    printFloat(gps.location.lng(), gps.location.isValid(), 12, 6);
    printDateTime(gps.date, gps.time);
    printFloat(gps.altitude.meters(), gps.altitude.isValid(), 7, 2);
    printFloat(gps.speed.kmph(), gps.speed.isValid(), 6, 2);
 */
    Serial.println();
    
    if(Hour_Reset > 90)
    {
      softReset();
    }
    
    wdt_reset();
    delay(5000);
    wdt_reset();
    
}

void sendNullData()
{
   wdt_reset();
    
    while(sendATcommand("AT+CIPSTART=\"TCP\",\"www.surinrobot.com\",\"80\"", "ALREADY CONNEC", 2000) == 0)
    {
      wdt_reset();
     Conn_Err++;
      if(Conn_Err > 20)
        { softReset();};
    };
    Serial.println("connected ok");
    
    wdt_reset();
    myGSM.println("AT+CIPSEND");
    delay(250);
    myGSM.print("GET /point/serverside/point_avr_post.php?lat=0.000000"); 
    Serial.print("GET /point/serverside/point_avr_post.php?lat=0.000000");
    delay(250);
    myGSM.print("&lon=0.000000");
    Serial.print("&lon=0.000000");
    delay(250);
     myGSM.print("&device_id=");
     Serial.print("&device_id=");
    delay(250);
    device_id();
    myGSM.print(Device_id);
    Serial.print(Device_id);
    delay(250);
  myGSM.print("&b=");
  Serial.print("&b=");
  delay(250);
  myGSM.print(build);
  Serial.print(build);
  delay(250);
  myGSM.print("&speed=999");
  Serial.print("&speed=999");
  delay(250);
  wdt_reset();
  myGSM.print(" HTTP/1.1\r\n");
  delay(500);
  myGSM.print("host:www.surinrobot.com\r\n");
  delay(250);
  wdt_reset();
  myGSM.print("Connection: Keep-Alive");         //working as well
  myGSM.print("\r\n");
  myGSM.print("\r\n");
  delay(250);
  wdt_reset();
  myGSM.write(0x1A);
  wdt_reset();
  delay(500);
  //myGSM.println();
  Serial.println("Complete"); 
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
        wdt_reset();
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
    sendATcommand("AT+IPR=9600", "OK", 2000);
    wdt_reset();
    /*** 
        check is the SIM presence and PIN code insertion
    ***/
    sendATcommand("AT+CPIN?", "+CPIN: READY", 2000); 
    
    /*** 
        Enable verbose
    ***/
    sendATcommand("AT+CMEE=1", "OK", 2000);
    wdt_reset();
    
    /*** 
        Rec as first ring
    ***/
    sendATcommand("ATS0=1", "OK", 2000);

    
    /***
        Set SMS as TEXT mode
    ***/
    sendATcommand("AT+CMGF=1", "OK", 2000);
    wdt_reset();
}

void InnitSim900()
{
  wdt_reset();
  device_id();
 delay(5000);
  
  wdt_reset();
  Serial.println(Device_id);

  if (myGSM.available()){
       while(String(Serial.write(myGSM.read())) == "Call Ready");
       wdt_reset();
      }

  Serial.println("Starting...");
    power_on();
    Serial.println("Connecting to the network...");
    /*
    int answer1 = sendATcommand("AT+CREG?", "+CREG: 1,5", 500);
        Serial.print("AT+CREG? = ");
    Serial.println(answer1);
    */
    while( sendATcommand2("AT+CREG?", "+CREG: 0,1", "+CREG: 1,1", 1000)== 0 )
    {
    wdt_reset();
        if(sendATcommand2("AT+CREG?", "+CREG: 0,5", "+CREG: 1,5", 1000))
        {
          Is_true = 1;
          break; 
        }
    };


      /***
        Attach to GPRS network
        
        Chech for attach Network
        
        AT+CGATT?
        +CGATT:0
        OK
    ***/
   while(sendATcommand("AT+CGATT=1", "OK", 7000)==0);

    wdt_reset();
    
    //while(sendATcommand("AT+CGDCONT=1,\"IP\",\"internet\"", "OK", 3000)==0);

    wdt_reset();
    /*
    if(Is_true == 1)
    {
      while(sendATcommand("AT+CSTT=\"internet\",\"TRUE\",\"TRUE\"", "OK", 7000)==0);
      wdt_reset();
      while(sendATcommand("AT+CIICR", "OK", 7000)==0)
      {
        wdt_reset();
        Conn_Err++;
      if(Conn_Err > 20)
        { softReset();};
      }
      wdt_reset();
      while(sendATcommand("AT+CIFSR", ".", 7000)==0);
      wdt_reset();
    }
    else{
      */
    while(sendATcommand("AT+SAPBR=3,1,\"APN\",\"internet\"", "OK", 3000)==0);
    
    
    //while(sendATcommand("AT+SAPBR=1,1", "OK", 3000)==0);
    //Serial.println("resister APN"); 
    wdt_reset();
    while(sendATcommand("AT+CIPSPRT=0", "OK", 3000)==0);
    
}

int8_t sendATcommand(char* ATcommand, char* expected_answer, unsigned int timeout){
  
    myGSM.listen();
    myGSM.flush();
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
  wdt_reset();
  Device_id = "";
  int value;
  for(int k = 0;k<6;k++) 
  {
     value = EEPROM.read(k);
     Device_id += (char)(value);
  }
}

boolean getGPS()
{
  while(!gps.location.isUpdated())
  {
    wdt_reset();
    smartDelay(10000);
    if(gps.location.isUpdated())
    {
      return true;
      break;
    }
    
    if(GPS_Error_Count == 60)
    {
      return false;
      break; 
    }
    
    GPS_Error_Count++;
  }
}
// This custom version of delay() ensures that the gps object
// is being "fed".
static void smartDelay(unsigned long ms)
{
  ss.listen();
  unsigned long start = 0;
  do 
  {
    wdt_reset();
    while (ss.available())
      gps.encode(ss.read());
      start++;
  } while (start < ms);
}

int8_t sendATcommand2(char* ATcommand, char* expected_answer1, char* expected_answer2, unsigned int timeout){
  
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
            // check if the desired answer 1  is in the response of the module
            if (strstr(response, expected_answer1) != NULL)    
            {
                answer = 1;
            }
            // check if the desired answer 2 is in the response of the module
            else if (strstr(response, expected_answer2) != NULL)    
            {
                answer = 2;
            }
        }
    }
    // Waits for the asnwer with time out
    while((answer == 0) && ((millis() - previous) < timeout));    

    Serial.print("Received--: ");
    Serial.println(response);
    return answer;
}

/***
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
***/
