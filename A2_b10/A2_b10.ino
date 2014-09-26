#include <TinyGPS++.h>
#include <SoftwareSerial.h>
#include <EEPROM.h>

#define build           10  //เปลี่ยนตาม build ที่ได้แก้ไข
#define SIM900SWITCH     7    //IO pin to switch GPRS on/off
#define SIM900STATUS     6    //IO pin to check if powered on
#define linkLED         13
#define SIMSIZE          3   //total storage space on SIM card
#define gsmRx            4   // Rx to Sim900
#define gsmTx            5   // Tx to Sim900

static const int gpsRx = 2, gpsTx = 3;
static const uint32_t GPSBaud = 9600;

String Device_id;
TinyGPSPlus gps;

int _gpsError;

char inChar;
int index;
char inData[200];

SoftwareSerial myGPS(gpsRx, gpsTx);
SoftwareSerial myGSM(gsmRx, gsmTx);

void setup()
{
  myGPS.begin(GPSBaud);
  myGSM.begin(9600);
  _gpsError = 0;
  Serial.begin(115200);
  
  pinMode(gpsRx, INPUT);
  pinMode(gpsTx, OUTPUT);
  pinMode(gsmRx, INPUT);
  pinMode(gsmTx, OUTPUT);
  

  
  pinMode(SIM900STATUS, INPUT);
  pinMode(SIM900SWITCH, OUTPUT);

  pinMode(linkLED, OUTPUT);
  
  digitalWrite(SIM900SWITCH, LOW);
  delay(3000);
  digitalWrite(SIM900SWITCH, HIGH);
  digitalWrite(linkLED, HIGH);
  
  device_id();
  delay(5000);
  /*
  Serial.println(Device_id);

  if (myGSM.available()){
       while(String(Serial.write(myGSM.read())) == "Call Ready");
      }

  Serial.println("Starting...");
    power_on();
    Serial.println("Connecting to the network...");
    int answer1 = sendATcommand("AT+CREG?", "+CREG: 1,5", 500);
        Serial.print("AT+CREG? = ");
    Serial.println(answer1);
    while(sendATcommand("AT+CREG?", "+CREG: 1,1", 500) == 0);
  Serial.println("connected");
  */
      /***
        Attach to GPRS network
        
        Chech for attach Network
        
        AT+CGATT?
        +CGATT:0
        OK
    ***/
    //while(sendATcommand("AT+CGATT=1", "OK", 3000)==0);
    //Serial.println("GPRS Attached");
    
          /***
        Attach to GPRS network
        
        Chech for attach Network
        
        AT+CGATT?
        +CGATT:0
        OK
    ***/
    //while(sendATcommand("AT+COPS=?", "OK", 3000)==0);
    //Serial.println("GPRS Attached");
    
   /***
       Query IP address
    ***/
    //while(sendATcommand("AT+CIFSR", "OK", 3000)==0);
    //Serial.println("GPRS IP pass");
   
}

void loop()
{
  Serial.println("ddd");
    smartDelay(1000);
    printFloat(gps.location.lat(), gps.location.isValid(), 11, 6);
    printFloat(gps.location.lng(), gps.location.isValid(), 12, 6);
    digitalWrite(linkLED, LOW);
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

static void smartDelay(unsigned long ms)
{
  unsigned long start = 0;
  do 
  {
    while (myGPS.available())
      gps.encode(myGPS.read());
      start++;
  } while (start < ms);
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

int8_t sendATcommand(char* ATcommand, char* expected_answer, unsigned int timeout){

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
