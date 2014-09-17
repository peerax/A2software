#include <avr/wdt.h>   //watchdog เป็นฟังก์ชั่นการตรวจสอบถ้ามีการ ติดลูปหรือ มีการ delay นานเกิน 8 วินาที จะทำการรีเซ็ตatmega328p-tu ทันที
#include <NewSoftSerial.h> //รับข้อมูลจากภายนอกเข้ามา และ นำข้อมูลส่งออก ตามตำแหน่งขาอินเตอร์เฟส ที่กำหนด
#include <TinyGPS.h>  //ดึง GPS
#include <PString.h>
#include <EEPROM.h>   //ออกและเขียนข้อมูลลง eeprom ในแต่ละแอดแดรส 0-255
#define BUFFSIZ 200
#define build 9  //เปลี่ยนตาม build ที่ได้แก้ไข
#define RETRY              1    //Number of times to retry turning GPRS on (0=none, 1 = 1 retry, etc.)
#define GPRSSWITCH         7    //IO pin to switch GPRS on/off
#define GPRSSTATUS         6    //IO pin to check if powered on
#define led                13
#define SIMSIZE            3   //total storage space on SIM card

uint8_t commandNumber = 0xFF;
int registeredOnNetwork = 1;
uint8_t replyMessageType = 0;
uint8_t index = 0;

const char *pleaseCall = "Please Call";
const char *CMGR = "AT+CMGR=";
const char *CMGD = "AT+CMGD=";
const char *CPMS = "AT+CPMS?";
const char *CREG = "AT+CREG?";

const char *googlePrefix = "https://maps.google.com/maps?q= ";
const char *SecurityCodeNumber = "1234";  //security code used in SMS messages
const char *defaultEmailAddress = "fluke49@gmail.com"; //default email address
//const int _machine = 8;  //ใว้เช็คว่ารถสตาร์ตอยู่ไหม
//const int _timer_PIN_01 = 9;  //เช็คเงื่อนไข time select
//const int _timer_PIN_02 = 10; //เช็คเงื่อนไข time select

int _timercheck = 0;
int _InputState00 = 0;
int _InputState01 = 0;
int _InputState02 = 0;
int _timerState = 0;
int _address = 0;    //ตำแหน่งของ EEPROM
int _ring = 0;
int _Count_off = 0;
int _GSM_State = 0;
int _GPRS_STATUS = 0;
int _GSM_POWER = 1;
int _GSM_Ready = 0;
int _check = 0;
int _check_1 = 0;
int _cuontCheckStatus;
int _CON_GSM = 0;
int _checkloop_in = 0;
int _checkloop_out = 0;
int _countconnectserver = 0;
int _intCount = 0;

byte ByteIn = 0;
byte value;

/*global variables*/
char rxBuffer[BUFFSIZ] = "";
char *defaultSMSAddress = "";
char loopBack[60] = "";
char *str;
char buffer[60];
char buffidx;

String CHAR_GPS01;   
String CHAR_GPS02;
String Device_id;


boolean ns = false;
boolean atError = false;
unsigned long _timeOut = 0;
  
NewSoftSerial mygsm(4, 5);      //กำหนดขา 4 เป็น RX, 5 เป็น TX เชื่อมต่อกับ GSM Module 
NewSoftSerial mygps(2, 3);      //กำหนดขา 2 เป็น RX, 3 เป็น TX เชื่อมต่อกับ GPS Module 

PString myString(buffer,sizeof(buffer));
TinyGPS gps;
void gpsdump(TinyGPS &gps);
bool feedgps();
void printFloat(double f, int digits = 2);
void device_id()
{
  _address = 0;
  myString.begin();      //เคลียร์  myString
  Device_id = '\0';
  for(int k = 0;k<6;k++) 
  {                      //อ่านค่าจาก EEPROM ในแต่ละ address จะต้องเปลี่ยนรอบการอ่านตามจำนวน ID
    value = EEPROM.read(_address);
    myString.print(value, BYTE); //เก็บค่าเป็น Byte
    _address = _address + 1; 
  }
    Device_id = String(myString);
}

void NO_CARRIER()        //เมื่อมีการโทรเข้ามาให้มาทำการตรวจสอบหาการวางสายหรือยัง
                         //เมื่อมีการวางสาย หรือปฏิเสธการรับสายจะมีการส่งค่า NO CARRIER ออกมาจาก sim 908 นำค่านีมาตรวจสอบแล้วกลับสู่การทำงานปกติ
{
  Serial.println("Have RING");
  wdt_disable();
  myString.begin();
  _checkloop_in = 0;
  while (_ring == 1){
    readATString(20000);
    Serial.println(rxBuffer);
    if(strstr(rxBuffer,"NO") != '\0'  ) 
    {
      _ring = 0;
      break;
    }
    _checkloop_in++;
    if(_checkloop_in >=60000)     //ทำหน้าที่ป้องกันการติดลูปการตรวจสอบหาการวางสาย ถ้าครบ 3-5 นาทีจะทำการวางสายทันที
    {
      mygsm.println("ATH");   //คำสั่ง ATH คือการวางสาย
      _ring = 0;
      break;
    }
  }
  Serial.println("NO_CARRIER");
  wdtSetup();
  _checkloop_in = 0;
}

void setup()
{
  Serial.begin(115200);
  mygsm.begin(9600);        //กำหนดให้ GSM ที่ 9600
  mygps.begin(9600);    // GPS หลายๆตัวที่ทดลองจะใช้ค่า rate ที่ 4800 และ 9600 ให้ปรับเปลี่ยนตามการทำงานของอุปกรณ์
  pinMode(GPRSSTATUS,INPUT);
  //pinMode(_machine,INPUT);
  //pinMode(_timer_PIN_01,INPUT);
  //pinMode(_timer_PIN_02,INPUT);
  pinMode(led, OUTPUT);         //ไฟแสดงสถานะการเชื่อมต่อเน็ต หรือการส่งค่าไปยัง server แล้ว
  pinMode(GPRSSWITCH,OUTPUT);
  digitalWrite(GPRSSWITCH,HIGH);  //หยุดการส่งสถานะ low เพื่อป้องกันการปล่อยสถานะlow มานานจะทำให้ เกิดการปิดอีกครั้ง
  digitalWrite(led,LOW); 
  myString.begin();   //เคลียร์  myString
  device_id();   //ทำการอ่านค่า device id จาก eeprom 
  Serial.println(Device_id);   //มอนิเตอร์มีเพื่อเช็คความถูกต้อง
  powerOnGPRS();
  wdtSetup();

}
void loop()// loop การทำงาน
{   
  Serial.println("Start loop");
  wdt_reset();
  powerOnGPRS();
  wdt_reset();
  _checkloop_in = 0;
  delay(1000);
  mygsm.println("AT+COPS?"); // คำสั่งใช้ในการตรวจสอบ หาผู้ให้บริการระบบโทรศัพท์ ส่งค่า AT+COPS? ไปสอบถาม GSM Module แล้วจะได้คำตอบกลับ  มาเพื่อเทียบค่าหาผู้ให้บริการ
  while(_CON_GSM == 0){
    readATString(15000);  // เก็บค่า string ที่ SIM548C-SIM900 ตอบกลับมาจากการส่งค่า AT+COPS?
    if( strstr(rxBuffer, "TRU") != '\0'  ) {
      _CON_GSM = 3;
      Serial.println("TRUE");
    }else{
      if( strstr(rxBuffer, "TRUE") != '\0'  ) {
        _CON_GSM = 3;
        Serial.println("TRUE");
      }
    }
    wdt_reset();
    _checkloop_in++;
    if (_checkloop_in == 30){
    break;
    }
  }
  _checkloop_in = 0;
  if (_CON_GSM == 3){
    mygsm.println("AT+CGDCONT=1,\"IP\",\"internet\"");        
    delay(500);
    mygsm.println("AT+CSTT=\"internet\",\"TRUE\",\"TRUE\"");        
    delay(500);
    mygsm.println("AT+CIICR");
    _checkloop_in = 0;     
    while (_check_1 == 0){
      readATString(20000);
      Processok();      // ใช้ในการตรวจสอบว่ามีการconfig okหรือไม่ ถ้า ok จึงจะส่งค่าได้ แต่ถ้าไม่ผ่านต้องทำการ reset GSM เพราะไม่พร้อมที่จะส่งค่า
      _checkloop_in++;
        if(_checkloop_in == 6){
          _check_1 = 1;
          _GSM_POWER = 0;
        }
    }
    _checkloop_in = 0;
    _check_1 = 0;
    _check = 0;
  }
  delay(250);
  wdt_reset();
  check_POWER_in:
  while (_GSM_POWER == 1)   // loop จะยังทำงานอยู่ ถ้า GSM ยังเปิด ก็คือ _GSM_POWER = 1 แต่ถ้า ตรวจสอบสถานะแล้ว GSM หลุด หรือสัญญาณไม่มีค่าที่ได้คือ _GSM_POWER = 0 จะหลุดจากloop แล้วรีเซ็ตเครื่อง
  { 
    Serial.print("_GSM_State = ");
    check_power();
    switch (_GSM_State)
    {
      case LOW:
      {
      Serial.println("LOW");
        _GSM_POWER = 0;
        goto check_POWER_in;
        break;
      }
      case HIGH:
      {
      Serial.println("HIGH");
      _check = 0;
      _countconnectserver = 0;   //เอาใว้สำหรับ นับจำนวนครั้งที่ไม่สามารถเชื่อมต่อ serversurinrobot ได้ ถ้าเชื่อมต่อไม่ได้ภายใน 20 ครั้งให้ทำการ รีเซ็ต คือจะได้ค่า _GSM_POWER = 0
      _GPRS_STATUS = 0;
      mygsm.println("AT+CIFSR");
      delay(500);
      if (_GSM_Ready == 1){
          Serial.print("_GPRS_STATUS    ");
          Serial.println(_GPRS_STATUS);
          Serial.print("_GSM_POWER    ");
          Serial.println(_GSM_POWER);
        while ( _GPRS_STATUS == 0 && _GSM_POWER == 1 )
        {
          rxBuffer[buffidx] = '0';
          myString.begin();
          wdt_reset();
          mygsm.println("AT+CIPSTATUS"); 
          _checkloop_in = 0; 
          while (_check == 0)
          {
            readATString(15000);
            ProcessATstatus();      
            _checkloop_in++;
              if(_checkloop_in >= 20)
              {
                break;
              }
            }
          _check = 0;
          rxBuffer[buffidx] = '0';
          delay(100);
          wdt_reset();
          _checkloop_out = 0;

          while (_GPRS_STATUS == 0){
            myString.begin();
            //Serial.println("Connecting Server");
            mygsm.println("AT+CIPSTART=\"TCP\",\"www.surinrobot.com\",\"80\"");  
            delay(500);
            _checkloop_in = 0;  
            while (_check == 0){
              readATString(15000);
              ProcessATstatus();      
              _checkloop_in++;                            
                if(_checkloop_in >= 10){            //ป้องกันการติดลูป ถ้าวนลูปถึง 10 ครั้งให้ออกมาจาก while
                  _check = 1;
                  break;
                }
            }
            _check = 0;
            _checkloop_out++;                         
                if(_checkloop_out >= 5){             //ป้องกันการติดลูป ถ้าวนลูปถึง 5 ครั้งให้ออกมาจาก while  
                  _GPRS_STATUS = 1;
                  break;
                }
          }
          _countconnectserver++;
          if (_countconnectserver >= 3){              //ป้องกันการติดลูป ถ้าวนลูปถึง 3 ครั้งให้ออกมาจาก while      
            _GSM_POWER = 0;
            break;
          }
        }
      }
      _GPRS_STATUS = 0;
      wdt_reset();
      mygsm.println("AT+CIPSEND");      
      delay(250);
      mygsm.print("GET /point/serverside/point_avr_post.php?lat="); 
      delay(250);
      wdt_reset();
      bool newdata = false;
      unsigned long start = millis();
      delay(10);
      while (millis() - start < 1000 && millis() > start){
        //Serial.println("feed gps");
        if (feedgps())
          newdata = true;
        }
        Serial.println(newdata);
        wdt_reset();
        if (newdata){
          myString.begin();
          gpsdump(gps);          

        }else{
          wdt_reset();
          mygsm.print(CHAR_GPS01);
          mygsm.print("&lon=");
          mygsm.print(CHAR_GPS02);
          //AGE();
          mygsm.print("&speed=999");
        }
      wdt_reset();
      //Serial.print("&device_id=");
      delay(100);
      mygsm.print("&device_id=");
      delay(250);
      device_id();
      Serial.print(Device_id);
      delay(250);
      mygsm.print(Device_id);
      delay(250);
      //Serial.print("&b=");
      mygsm.print("&b=");
      delay(250);
      Serial.print(build);
      mygsm.print(build);
      delay(250);
      //Serial.println(" HTTP/1.1");
      mygsm.println(" HTTP/1.1");   //HTTP/1.1 ต้อง enter 2 ครั้งก่อนจบการทำงานด้วย Ctrl+Z ส่วน HTTP/1.0 enter ครั้งเดียว ตามหลักการทำงาน potocal
      delay(250);
      //Serial.println("host:www.surinrobot.com");
      mygsm.println("host:www.surinrobot.com");  
      delay(250);
      mygsm.println("");             
      delay(250);
      mygsm.println(0x1A,BYTE);      //เป็นคำสั่งส่งค่า หรือ Ctrl+Z นั้นเอง 
      Serial.println("Ctrl+Z");  
      delay(1500);
      //toSerial();
      wdt_reset();
      mygsm.println("");
      mygsm.println("AT+CIPCLOSE = 1");
      delay(1000);
      digitalWrite(led,LOW);      //LED pin 13 จะดับเพื่อบอกว่าสิ้นสุดการส่งค่า หรือ เพื่อให้รู้ว่าไม่มีการทำคำสั่งการส่งค่าไปยังserve
      wdt_reset();
      _checkloop_in = 0;  
      _GSM_Ready = 1;
      _check = 0;
      //check_timer();
      //wdtSetup();
      Serial.println("passwdt");
      Check_SMS();
      if (_ring == 1)
        {
          NO_CARRIER();
          _ring = 0;
        }
      break;
    }
    }    
  } 
   if (_Count_off >= 6)
   {           //ถ้าเชื่อมต่อเน็ตไม่ได้เป็นจำนวน 20 รอบของ loop การทำงาน ให้ทำการปิด SIM900 เพื่อแก้ปัญหาการเปลี่ยนแปลงค่าระหว่าง ระบบผู้ให้บริการกับ sim 900 ก็ให้เกิดการค้างของ sim900
      wdtSetup();
      Serial.println("RESTART GSM AVR");
      detachInterrupt(1);
      digitalWrite(GPRSSWITCH,LOW);    // เปิดการทำงาน gsm board โดย GSM bord จะทำงานที่สถานะ low  
      delay(1500);
      digitalWrite(GPRSSWITCH,HIGH);  //หยุดการส่งสถานะ low เพื่อป้องกันการปล่อยสถานะlow มานานจะทำให้ เกิดการปิดอีกครั้ง
      _Count_off =0;                                 //รีเซ็ตจำนวนรอบ _Count_off 
      _GSM_POWER = 0;
      delay(9000);
    }
    //Serial.println(_Count_off);
    _Count_off++;                                // +เพิ่มที่ละ 1 เมื่อครบ 10 จะปิด sim900 และ รีเซ็ต atmega328p
      
   // สิ้นสุดการทำงานการส่งค่า GPS ไปยัง surinrobot ทำการปิด GSM module แล้วเริ่มการทำงานใหม่  รีเซ็ตตัวแปรต่างๆให้กลับสู่ค่าเริ่มต้นในการทำงานใหม่ทั้งหมด ป้องกันการจำค่าเดิม
  _ring = 0;
  _check = 0;
  _check_1 = 0;
  _GSM_Ready = 0;
  _GPRS_STATUS = 0;
}

void toSerial()
{
  while(mygsm.available()!=0)
  {
    Serial.write(mygsm.read());
  }
}

void Check_SMS(){
  myString.begin();
      wdt_reset();
      sendATCommand(CPMS,rxBuffer,10,0,false);  //check for new messages
      uint8_t unread = checkForMessages(rxBuffer);
      Serial.println("check SMS");
      if (unread > 0) //if there are unread messages stored on the SIM card then read them
      { 
        Serial.println("unread > 0");
        commandNumber = 0xFF;
        wdt_reset();
        uint8_t MessExec = 0; //number of messages successfully read
        for (uint8_t lp = 0; lp < SIMSIZE; lp++) //loop no more than the total available on the sim card
        { 
          wdt_reset();
          if(MessExec == unread) //finsh loop after last message read
          { 
            Serial.println("unread");
            //return;
            break;
          }
          wdt_reset();
          sendATCommand(CMGR,rxBuffer,15,lp+1,true);  //read the message number (loop number + 1)
          if(strlen(rxBuffer)<20) //blank message on SIM, move onto next memory location on sim card
          {  
            wdt_reset();
            Serial.print("<20");
            sendATCommand(CMGD,rxBuffer,15,lp+1,true);
            MessExec++;  //increment if a message was read off the sim card
            continue;
          }
          wdt_reset();
          //uint8_t replyMessageType = 0;
          replyMessageType = 0;
          if(strstr(rxBuffer,pleaseCall)!=NULL) //if we don't see please call message is not a page
          {
            wdt_reset();
            Serial.println("pleaseCall");
            replyMessageType = 0; //loopback message type is a page
          }
          
          else if(strstr(rxBuffer,"@")!=NULL) //check to see if message is an email
          { 
            wdt_reset();
            Serial.println("@");
            replyMessageType = 2; //loopback message type is an email
          }
          else
          {
            wdt_reset();
            Serial.println("replyMessageType = 1");
            replyMessageType = 1;  //loopback message type is an SMS
          }
          wdt_reset();
          if(!SMSEmailPage(rxBuffer,SecurityCodeNumber,&commandNumber,replyMessageType)) //Message is an SMS
          {
            Serial.println("SMSEmailPage");
            wdt_reset();
            executeSMSCommand(commandNumber,rxBuffer,loopBack,replyMessageType);
          }
          wdt_reset();
          sendATCommand(CMGD,rxBuffer,15,lp+1,true);
          wdt_reset();
          MessExec++;  //increment if a message was read off the sim card
          continue;
        }
      }
}
void printFloat(double number, int digits){  //ฟังก์ชั่น การคำนวณหา ละติจูด ลองติจูด เพื่อให้ตรงตามมารตฐานเพื่อที่จะนำไปใช้กับ google map ได้ทันที 
  //
  if (number < 0.0){
     myString.print('-');
     number = -number;
  }
  wdt_reset();
  double rounding = 0.5;
  for (uint8_t i=0; i<digits; ++i)
      rounding /= 10.0;
  number += rounding;
  unsigned long int_part = (unsigned long)number;
  double remainder = number - (double)int_part;
  myString.print(int_part);
  wdt_reset();
  if (digits > 0)
    myString.print("."); 
    while (digits-- > 0)
  {
    remainder *= 10.0;
    int toPrint = int(remainder);
    myString.print(toPrint);
    remainder -= toPrint; 
    wdt_reset();
    
  }
}
 
 void gpsdump_2(TinyGPS &gps){                                        //เก็บค่าละติจูด ลองติจูด และสปีดจาก GPS ลงใน myString 
   long lat, lon;
   float flat, flon;
   unsigned long age, date, time, chars;
   int year;
   byte month, day, hour, minute, second, hundredths;
   gps.f_get_position(&flat, &flon, &age);
   printFloat(flat, 5);
   myString.print(","); 
   printFloat(flon, 5);
   mygsm.print(myString);
   myString.begin();
 }
 
 void gpsdump(TinyGPS &gps){    //เก็บค่าละติจูด ลองติจูด และสปีดจาก GPS ลงใน myString 
   Serial.println("NEW DATA GPS");
   myString.begin();
   long lat, lon;
   float flat, flon;
   unsigned long age, date, time, chars;
   int year;
   byte month, day, hour, minute, second, hundredths;
   gps.f_get_position(&flat, &flon, &age);
   wdt_reset();
   printFloat(flat, 5);
   mygsm.print(myString);
   CHAR_GPS01=String(myString);  //*****
   mygsm.print("&lon=");
   myString.begin();
   wdt_reset();
   printFloat(flon, 5);
   mygsm.print(myString);
   CHAR_GPS02=String(myString);   //****
   wdt_reset();
   //AGE();
   myString.begin();
   myString.print("&speed=");
   wdt_reset();
   printFloat(gps.f_speed_kmph());
   mygsm.print(myString);
   myString.begin();
   wdt_reset();
 }
bool feedgps()
{
  //
  while (mygps.available())
  {
    if (gps.encode(mygps.read()))
    return true;
  }

  return false;
   
}
   /* Reads AT String from the SIM548C GSM/GPRS Module */
void readATString(int _cuontCheckStatus) 
{      // function \u0e19\u0e35\u0e49\u0e40\u0e2d\u0e32\u0e44\u0e27\u0e49\u0e40\u0e01\u0e47\u0e1a\u0e04\u0e48\u0e32 string \u0e17\u0e35\u0e48\u0e44\u0e14\u0e49\u0e23\u0e31\u0e1a\u0e08\u0e32\u0e01 gsm
  char c;
  buffidx= 0; // start at begninning
  c=0;
  _intCount = 0;
  //
  while (1) { 
    _intCount++;
    if (_intCount > _cuontCheckStatus){
      return;
    }
    if(mygsm.available()>0) {
      c=mygsm.read();
      if (c == -1) {
        rxBuffer[buffidx] = '\0';
        return;
      }
      if (c == '\n') {
        continue;
      }
      if ((buffidx == BUFFSIZ - 1) || (c == '\r')){
        rxBuffer[buffidx] = '\0';
        return;
      }
      rxBuffer[buffidx++]= c;
    }
    
  }

}    
void readATString_Check(int _cuontCheckStatus) 
{
    char c;
    buffidx= 0; // start at begninning
    c=0;
    _intCount = 0;
    while (1) { 
      _intCount++;
      if (_intCount > _cuontCheckStatus){
        _check = 1; 
        return;
      }
      if(mygsm.available()>0) {
        c=mygsm.read();
        if (c == -1) {
          rxBuffer[buffidx] = '\0';
          return;
        }
        if (c == '\n') {
          continue;
        }
        if ((buffidx == BUFFSIZ - 1) || (c == '\r')){
          rxBuffer[buffidx] = '\0';
          return;
        }
        rxBuffer[buffidx++]= c;
        Serial.println(rxBuffer);
      }
    }

}   
                                                              
void ProcessATstatus() {   // ฟังก์ชั่นการเทียบค่า string ที่เก็บใน at_buffer ในฟังก์ชั่น readATString()  ค่าที่ได้ได้จากการ ส่งคำสั่ง AT+CIPSTATUS ไปเพื่อสอบถามว่า GSM 
  if( strstr(rxBuffer, "IN") != '\0'  ) {
        _GPRS_STATUS=1;
        _GSM_POWER = 0;
         _check=1;
        Serial.println("IP GPRS NOT READY");
      }
    
    else if( strstr(rxBuffer, "TC") != '\0'  ) {
      _GPRS_STATUS = 0;
      _check = 1;
    }
      
    else if( strstr(rxBuffer, "TU") != '\0'  ) {
      _GPRS_STATUS = 0;
      _check = 1;
    }
      else if( strstr(rxBuffer, "RE") != '\0'  ) {
        _GPRS_STATUS = 1;
        digitalWrite(led,HIGH);          // LED pin 13 จะสว่างเพื่อแสดงสถานะว่าเริ่มคำสั่งการส่งข้อมูล
        Serial.println("READY CONNECT");
    }
      else if( strstr(rxBuffer, "CONNECT OK") != '\0'  ) {
        _GPRS_STATUS = 1;
        _check = 1;
        _Count_off = 0;
        _timercheck = 1;
        digitalWrite(led,HIGH);          // LED pin 13 จะสว่างเพื่อแสดงสถานะว่าเริ่มคำสั่งการส่งข้อมูล
        Serial.println("CONNECT OK");
    }
     if( strstr(rxBuffer, "CARRIER") != '\0'  ) {
          _ring = 0;
          Serial.println("NO CARRIER");
        }
       
}

void Processok() {
  
  if( strstr(rxBuffer, "OK") != '\0'  ) {
      _check = 1;
      _check_1 = 1;
      _GSM_POWER = 1;
    }
  
}
void wdtSetup() {
 cli();
 MCUSR = 0;

  WDTCSR = ((1 << WDCE) | (1 << WDE));		
  WDTCSR = ((1 << WDIE) | (1 << WDP0) | (1 << WDP3));  // ที่มา http://avrusbmodem.googlecode.com/svn-history/r37/trunk/USBModem.c

sei();
 }
 void check_power(){
 for (int i=0;i<3;i++){
    _GSM_State=digitalRead(GPRSSTATUS);
    delay(50);
    }
 }
void powerOnGPRS(){
    check_power();
    if(_GSM_State==LOW)
    {
      wdt_reset();
      Serial.println("POWER GSM LOW");
      digitalWrite(GPRSSWITCH,LOW); //send signal to turn on
      delay(1200);  //signal needs to be low for 1 second to turn GPRS on
      digitalWrite(GPRSSWITCH,HIGH);
      delay(2400);
      unsigned long timeOut = millis();
      uint8_t index = 0;
      while ( millis() <= timeOut + 5000)
      {
        if(mygsm.available())
        {
          rxBuffer[index] = mygsm.read();
          index++;
        }
        if(strstr(rxBuffer,"Call Ready") != NULL)
        {
          Serial.println("Call Ready");
          break; //GPRS is registered on the network
        }
      }
      delay(3000);
      wdt_reset();
      delay(7000);
      check_power();
    }
 
    if(_GSM_State==HIGH)
      { 
        wdt_reset();
        Serial.println("POWER GSM HIGH");
        registeredOnNetwork = checkNetworkRegistration();
        Serial.println("off check network");
        Serial.println(registeredOnNetwork);
        if(registeredOnNetwork == 1)
          {
            Serial.println("no network");
            return; 
          }
          wdt_reset();
          if (_GSM_POWER == 1){
            Serial.println("config GSM");
            mygsm.println("ATV1");
            delay(250);
            mygsm.println("AT+IPR=9600");
            delay(250);
            mygsm.println("ATS0=2");   //คำสั่ง การรับสาย auto เมื่อมีสัญญาณโทรเข้า ติดต่อกัน 2 ครั้ง
            delay(250);
            mygsm.println("AT+CMGF=1");  
            delay(250);
            mygsm.println("AT+CREG=1");    //Serial.println("AT+CREG=1");    
            delay(250);
            mygsm.println("AT+CGATT=1");      
            delay(250);
            mygsm.println("AT+CNMI=0,0,0,0,0");
            delay(250);
            mygsm.println("AT&W"); 
            delay(250);
          }
      }
      wdt_reset();
        
}

int checkNetworkRegistration()           //เช็คความพร้อมของเครื่อข่าย
{
  wdt_reset();
  sendATCommand(CREG,rxBuffer,30,0,false);  //check network registration status
  if(strstr(rxBuffer,",1") != NULL || strstr(rxBuffer,",5") != NULL)
  {
    _GSM_POWER = 1;
    return 0; //GPRS is registered on the network
  }
  return 1; //GPRS is not registered on the network
}

uint8_t sendATCommand(const char *atCommand,char *buffer, int atTimeOut,int smsNumber,boolean YN)
{
  wdt_reset();
  atError = false;
  index = 0;
  _timeOut = 0;
  //();
  for (uint8_t SAT = 0; SAT < 3; SAT++)
  {
    wdt_reset();
    atError = false;
    buffer[0] = '\0';
    index = 0;
    if (YN)
    {
      mygsm.print(atCommand);
      mygsm.println(smsNumber);
    }
    else 
    {
      mygsm.println(atCommand);
    }
    _timeOut = millis() + (1000*atTimeOut);
    int i = 0;
    delay(10);
    while (i<500  /*millis() < _timeOut*/)
    {
      Serial.print(millis());
      Serial.print(" to ");
      Serial.println(_timeOut);
      wdt_reset();
      if (mygsm.available())
      {
        buffer[index] = mygsm.read();
        index++;
        buffer[index] = '\0';
        if(strstr(buffer,"ERROR")!=NULL) //if there is an error send AT command again
        {
          atError = true;
          break;
        }
        if(strstr(buffer,"OK")!=NULL) //if there is no error then done
        {
          //();
          return(0);
        }
        if (index == 198) //Buffer is full
        { 
          return(1);
        }
      }
      i++;
    }
    Serial.println("out at command loop");
    if(atError)
    {
      continue;
    }
    mygsm.println("AT");// DEBUG
    delay(500);// DEBUG
    break;
  }
  return(2);
}

uint8_t executeSMSCommand(uint8_t _commandNumber,char *_rxBuffer,char *_replyBack, uint8_t _replyMessageType)
{
  //Serial.print("executeSMS");
  wdt_reset();
  //unsigned long timeOut;
  //byte ByteIn = 0;
  //boolean ns = false;
  ByteIn = 0;
  ns = false;
  _timeOut = 0;
  
  switch(_commandNumber){
  case 0:    //callback
    {
      Serial.println("case 0:");
      wdt_reset();
      if(_replyMessageType == 0){
        _replyMessageType = 1;
        
        strcpy(_replyBack,defaultSMSAddress);
      }
      if(_replyMessageType == 1)
      {
        _ring =1;
        mygsm.print("ATD");
        delay(250);
        mygsm.print(_replyBack);
        delay(250);
        mygsm.println(";");
        delay(250);
      }
      else
      {
        mygsm.println("AT+CMGS=\"500\"");
      }
      
      _timeOut = millis();
      while (millis() < _timeOut + 2000)
      {
        if(mygsm.available())
        {
          if(mygsm.read() == '>')
          {
            ns = true;
            break;
          }
        }
      }
      if(!ns)
      {
        mygsm.println(0x1B,BYTE); //do not send message
        delay(250);
        return(1);
      } //There was an error waiting for the > 
      if(_replyMessageType == 2)
      {
        mygsm.println(_replyBack);
      }
      delay(5000);
    }
    break;
    case 1:    //restart
    {
      Serial.println("case 1:");
      wdtSetup();
      for (uint8_t lp = 0; lp < SIMSIZE; lp++) //loop no more than the total available on the sim card
        { 
      sendATCommand(CMGR,rxBuffer,15,lp+1,true);  //read the message number (loop number + 1)
      wdt_reset();
      sendATCommand(CMGD,rxBuffer,15,lp+1,true);
      wdt_reset();
        }
      Serial.println("RESTART GSM AVR");
      detachInterrupt(1);
      detachInterrupt(0);
      digitalWrite(GPRSSWITCH,LOW);    // เปิดการทำงาน gsm board โดย GSM bord จะทำงานที่สถานะ low  
      delay(1100);
      digitalWrite(GPRSSWITCH,HIGH);  //หยุดการส่งสถานะ low เพื่อป้องกันการปล่อยสถานะlow มานานจะทำให้ เกิดการปิดอีกครั้ง
      _Count_off =0;                                 //รีเซ็ตจำนวนรอบ _Count_off 
      _GSM_POWER = 0;
      delay(9000);
    }
    break;
  case 2:
  {
    //call_in
    Serial.println("case 2:");
    mygsm.println("ATS0=2");
    delay(1000);
    wdt_reset();
      if(_replyMessageType == 0)
      {
        _replyMessageType = 1;
        strcpy(_replyBack,defaultSMSAddress);
      }
      if(_replyMessageType == 1)
      {
        mygsm.print("AT+CMGS=\"");
        mygsm.print(_replyBack);
        mygsm.println("\"");
      }
      else
      {
        mygsm.println("AT+CMGS=\"500\"");
      }
      _timeOut = millis();
      wdt_reset();
      while (millis() < _timeOut + 2000)
      {
        wdt_reset();
        if(mygsm.available())
        {
          wdt_reset();
          if(mygsm.read() == '>')
          {
            ns = true;
            break;
          }
        }
      }
      if(!ns)
      {
        mygsm.println(0x1B,BYTE); //do not send message
        delay(500);
        //();
        return(1);
      } //There was an error waiting for the > 
      if(_replyMessageType == 2)
      {
        mygsm.println(_replyBack);
      } 
      //mygsm.print(utcTime);
      //mygsm.print(",");
      //mygsm.println(date);
      mygsm.println("Ready to go");
      _ring = 0;
    mygsm.println("");
    mygsm.println(0x1A,BYTE);
    delay(500);
    wdt_disable();
    delay(500);
    myString.begin();
    //();
    _checkloop_in = 0;
    Serial.print("_ring = ");
    Serial.println(_ring);
    _timeOut = millis();
    while (millis() < _timeOut + 60000)
    {
      readATString(20000);
      if(strstr(rxBuffer,"RING") != '\0'  ) 
        {
          _ring = 1;
          break;
        }
    }
      while (_ring == 1){
        readATString(20000);
        Serial.println(rxBuffer);
        if(strstr(rxBuffer,"NO") != '\0'  ) 
        {
          _ring = 0;
          break;
        }
        _checkloop_in++;
        if(_checkloop_in >=60000)     //ทำหน้าที่ป้องกันการติดลูปการตรวจสอบหาการวางสาย ถ้าครบ 3-5 นาทีจะทำการวางสายทันที
        {
          mygsm.println("ATH");   //คำสั่ง ATH คือการวางสาย
          _ring = 0;
          break;
        }
      }
    
    mygsm.print("AT+CMGS=\"");
    delay(500);
    mygsm.print(_replyBack);
    delay(500);
    mygsm.println("\"");
    delay(500);
    mygsm.println("Close");
    delay(500);
    mygsm.println("");
    mygsm.println(0x1A,BYTE);
     uint8_t idx = 0;
      ns = false;
      _timeOut = millis();
      while (millis() < _timeOut + 60000)
      {wdt_reset();
        if (mygsm.available()){
          _rxBuffer[idx] = mygsm.read();
          idx++;
          _rxBuffer[idx] = '\0';
          if(strstr(_rxBuffer,"ERROR")!= NULL)
          {
           // mygsm.println("ERROR SENDING");
            delay(500);
            //();
            return(2);
          }
          wdt_reset();
          if(strstr(_rxBuffer,"+CMGS:")!= NULL)
          {
           // mygsm.println("MESSAGE SENT");
            delay(500);
            //();
            return(0);
          }
        }
      }
    delay(1000);
    return(3);
   }
    break;
  case 3:  //send lat long back
  {
    Serial.println("case 3:");
    wdt_reset();
    //Serial.println("99");
      if(_replyMessageType == 0)
      {
        _replyMessageType = 1;
        strcpy(_replyBack,defaultSMSAddress);
      }
      //Serial.println("100");
      if(_replyMessageType == 1)
      {
        mygsm.print("AT+CMGS=\"");
        mygsm.print(_replyBack);
        mygsm.println("\"");
      }
      else
      {
        mygsm.println("AT+CMGS=\"500\"");
      }
      
      _timeOut = millis();
      //Serial.println("101");
      wdt_reset();
      while (millis() < _timeOut + 2000)
      {wdt_reset();
        if(mygsm.available())
        {
          wdt_reset();
          if(mygsm.read() == '>')
          {
            ns = true;
            break;
          }
        }
      }
      //Serial.println("102");
      if(!ns)
      {
        mygsm.println(0x1B,BYTE); //do not send message
        delay(500);
        //();
        return(1);
      } //There was an error waiting for the > 
      if(_replyMessageType == 2)
      {
        mygsm.println(_replyBack);
      } 
      mygsm.println("!!! SECURITY ALERT !!!");
    }
    break;
  default:
    //();
    return(4);
  }
  mygsm.print(googlePrefix);
  bool newdata = false;
      unsigned long start = millis();
      while (millis() - start < 1000){
        wdt_reset();
          if (feedgps())
            newdata = true;
          }
          if (newdata){
            myString.begin();
            gpsdump_2(gps);
          }
          delay(1000);
      mygsm.println("");
  
  //mygsm.println(googleSuffix);
  mygsm.println(0x1A,BYTE);
  uint8_t idx = 0;
  ns = false;
  _timeOut = millis();
  while (millis() < _timeOut + 60000)
  {wdt_reset();
    if (mygsm.available()){
      _rxBuffer[idx] = mygsm.read();
      idx++;
      _rxBuffer[idx] = '\0';
      if(strstr(_rxBuffer,"ERROR")!= NULL)
      {
       // mygsm.println("ERROR SENDING");
        delay(500);
        //();
        return(2);
      }
      wdt_reset();
      if(strstr(_rxBuffer,"+CMGS:")!= NULL)
      {
       // mygsm.println("MESSAGE SENT");
        delay(500);
        //();
        return(0);
      }
    }
  }
  delay(500);
  //();
  return(3);
}
/*This procedure will check if message is an SMS, if it is it will verify security code and will 
 log what the action is to be performed. The return value will dictate how the procedure was done
 return 1 - Message was successfully read and code was authorized, no commands found
 return 2 - Message was successfully read and code was authorized, command found
 return 3 - Message was successfully read and code was not authorized
 */

uint8_t SMSEmailPage(char *ptr,const char *_SecurityCodeNumber,uint8_t *_commandNumber,uint8_t _replyMessageType)
{
  if(_replyMessageType == 0) //message is a page
  {
    ptr = strtok_r(ptr,":",&str);
    ptr = strtok_r(NULL,"\n",&str);
    ptr = strtok_r(NULL,"\"",&str);
    ptr = strtok_r(NULL,"\"",&str);
    if(strncmp(ptr,_SecurityCodeNumber,4)!= 0)
    {
      return(1); //invalid security code
    }
    ptr[0] = '0';
    ptr[1] = '0';
    ptr[2] = '0';
    ptr[3] = '0';
    *_commandNumber = atoi(ptr);
    return(0);
  }
  if(_replyMessageType == 1) //message is an SMS
  {
    ptr = strtok_r(ptr,":",&str);
    ptr = strtok_r(NULL,"\"",&str);  //loopback
    ptr = strtok_r(NULL,"\"",&str);  //loopback
    ptr = strtok_r(NULL,"\"",&str);  //loopback
    ptr = strtok_r(NULL,"\"",&str);  //loopback
    //Serial.println("SMS");
    wdt_reset();
    //strcpy(defaultSMSAddress,ptr);
    //wdt_reset();
    //Serial.println(ptr);
    if (strlen(ptr) < 40)  //if phone number is 39 digits or less then it's OK to use
    {
      strcpy(loopBack,ptr);
    }
    ptr = strtok_r(NULL,"\n",&str);
    ptr = strtok_r(NULL,":",&str);
    ptr = ptr + (strlen(ptr)-4);
    if(strncmp(ptr,SecurityCodeNumber,4)!= 0)
    {
      return(1); //invalid security code
    }
    ptr = strtok_r(NULL,":",&str);
    *_commandNumber = atoi(ptr);
    return(0);
  }
  if(_replyMessageType == 2) //message is an email
  {
    ptr = strtok_r(ptr,":",&str);
    ptr = strtok_r(NULL,"\n",&str); 
    ptr = strtok_r(NULL,"/",&str);
    if (strlen(ptr) < 40)  //if email address is 39 digits or less then it's OK to use
    {
      strcpy(loopBack,ptr);
    }
    for(uint8_t ws = 0; ws < strlen(loopBack); ws++)
    {
      if(loopBack[ws] == ' ')
      {
        loopBack[ws] = '\0';
      }
    }
    ptr = strtok_r(NULL,"/",&str);
    ptr = strtok_r(NULL,":",&str);
    ptr = ptr + (strlen(ptr)-4);
    if(strncmp(ptr,SecurityCodeNumber,4)!= 0)
    {
      return(1);
    }
    ptr = strtok_r(NULL,":",&str);
    *_commandNumber = atoi(ptr);
    return(0);
  }
}



uint8_t checkForMessages(char *ptr)
{
  uint8_t receivedMessages = 0;  //total unread messages stored on the SIM card
  ptr = strtok_r(ptr,",",&str);
  ptr = strtok_r(NULL,",",&str);
  receivedMessages = atoi(ptr);  //Number of messages on the sim card
  return(receivedMessages);
}
/*void check_timer()
{
  wdt_disable();
  _InputState01 = digitalRead(_timer_PIN_01);
  _InputState02 = digitalRead(_timer_PIN_02);
  if(_InputState01==HIGH&&_InputState02==HIGH&&_timercheck == 1){
    _timerState = 1;
   Serial.println("timer 10 sec");
  }
  else{
    if(_InputState01==LOW&&_InputState02==HIGH&&_timercheck == 1){
      _timerState = 2;
      Serial.println("timer 30sec");
      //delay(20000);  
      delay(9000);
    }
    else{
      if(_InputState01==LOW&&_InputState02==LOW&&_timercheck == 1){
        _timerState = 3;
        Serial.println("timer 5");
        Check_SMS();
        delay(268000);
      }
      else{
        if(_InputState01==HIGH&&_InputState02==LOW&&_timercheck == 1){
          _timerState = 4;
          Serial.println("timer 30");
          Check_SMS();
          delay(280000);
          Check_SMS();
          delay(280000);
          Check_SMS();
          delay(280000);
          Check_SMS();
          delay(278000);
          Check_SMS();
          delay(280000);
          Check_SMS();
          delay(278000);
          //delay(1778000);
        }
      }
    }
  }
  wdtSetup();
  wdt_reset();
  _InputState01=0;
  _InputState02=0;
  _timercheck = 0;
}
void AGE(){
   mygsm.print("&age=");
   _InputState00 = digitalRead(_machine);
   if(_InputState00==HIGH){
     mygsm.print("1");
   
   }else{
     mygsm.print("0");

   }
   
}*/

