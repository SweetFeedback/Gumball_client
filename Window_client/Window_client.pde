import processing.serial.*;
import org.json.*;
import controlP5.*;
import ddf.minim.*;
import java.net.*;

private static String mWindowDeviceId = null;
private static Serial mPort =null;
private static String mPortName = null;

private static String URL = "php/insertSensorValueToDbNew.php";
private static String URL_updateWindowState = "php/insertExtendedWindowState.php";
private String mHostName = null;
private String inBuffer = null;
private int bootError = 0;
private int[] prevWindowStates;
int WIDTH = 360;
int HEIGHT = 200;
int FULL_WIDTH = 370;
int FULL_HEIGTH = 480;
int TEXT_HEIGHT = HEIGHT/2+40;
int margin_width = 10;
int margin_height = TEXT_HEIGHT + 10;
int[] windowIdList=null;
PFont Font01;
PFont metaBold;
Minim minim;
AudioPlayer player;
/***
 Main Functions
 ***/
void setup() {

  size(WIDTH, HEIGHT);
  //PFont f = createFont("Arial", 20, true);
  //textFont(f);
  //PFont metaBold;
  metaBold = loadFont("SansSerif-48.vlw");
  Font01 = loadFont("SansSerif-48.vlw");
  textFont(metaBold, 24);

  //frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
  getSettings();
  portOpen(mPortName);
  askForWindowId(mPort);
  
  if(mPort == null|| mPort.output == null){
    bootError = 1;
  }

  if(bootError == 0 && loadStrings(mHostName) == null){
    bootError = 2;
  }
  
  minim = new Minim (this);
  player = minim.loadFile ("../audio/wind.wav");

  
}

void draw() {
  background(128);
  if(bootError > 0){
    switch(bootError){
      case 1:
        text("Cannot open port: ", 10, HEIGHT/4 - 20);
        text(mPortName, 10, HEIGHT/4 + 10);
        break;
      case 2:
        text("Cannot connect server: ", 10, HEIGHT/4 - 20);
        text(mHostName, 10, HEIGHT/4 + 10, 300, 24);
        break;
      default:
        text("Unknown boot error", 10, HEIGHT/4 - 20);
        break;
    }
  }else{
    text("windows State Data:", 10, HEIGHT/4 - 20);
    text("S(dB), Li, T, IR, Win", 10, HEIGHT/4+10);
    if (inBuffer != null) {
      text(inBuffer, 8, height/2 - 10);      
    }

  }
}


void serialEvent(Serial myPort) {
  /**/
  String tmpBuffer = myPort.readStringUntil('\n');
  if (tmpBuffer != null) {
    tmpBuffer = trim(tmpBuffer);
    inBuffer = tmpBuffer;
    String[] splited_str = tmpBuffer.split(":");
    if(splited_str.length != 2)
      return; //ignore if the data format is not correct
    String dataProperty = splited_str[0];
    
    //println(dataProperty);
    if (dataProperty.equals("data")){
        if(windowIdList==null){
          askForWindowId(myPort);
          return;
        }
        String[] splited_data = splited_str[1].split(",");
        int openWindowCnt = 0;
        for(int i = 0; i < splited_data.length; i++){
          int newWindowState = Integer.parseInt(splited_data[i]);
          if(newWindowState == 1)
            openWindowCnt+=1;
          if(newWindowState != prevWindowStates[i]){
            prevWindowStates[i] = newWindowState; 
            insertWindowDataToServer(String.valueOf(windowIdList[i]), newWindowState);
          }
          utterWindSound(openWindowCnt>0);
          
        }      

    }
    else if(dataProperty.equals("windowId")){
      //println(splited_str[1]);
      setWindowIdList(splited_str[1]);
    }
    //assert(splited_data.length == windowIdList.length);
    
    
    
    
    
  }
  if(bootError == 0) {
    askForWindowStateData(myPort);
  }else{
    myPort.write('z');
    //println("only establish contact");
  }
}

void dispose(){
  mPort.clear();
  mPort.stop();
  super.dispose();
}

boolean isWindowOpenTimeMatched(){
  Date date = new Date();
  String strDateFormat = "HH";
  SimpleDateFormat sdf = new SimpleDateFormat(strDateFormat);
  int hour = Integer.parseInt(sdf.format(date));
  println(hour);
  if(hour>=8 && hour<=19)
    return false;
  return true;
}
/***
 Functions related to port 
 ***/
private void portOpen(String name){
  if (name != "") {
    mPort = new Serial(this, name, 9600);
    mPort.clear();
    // read bytes into a buffer until you get a linefeed (ASCII 10):
    mPort.bufferUntil('\n');
  }
}

private void  setWindowIdList(String windowDeviceIdStr){
  String[] splited_data = windowDeviceIdStr.split(",");
  windowIdList = new int[splited_data.length];
  prevWindowStates = new int[splited_data.length];
    for(int i = 0; i < splited_data.length; i++){
          windowIdList[i] = Integer.parseInt(splited_data[i]);
          prevWindowStates[i] = -1;
  }

}
private void askForWindowStateData(Serial port) {
  if (port != null) {
    port.write('B');
  }
}
private void askForWindowId(Serial port) {
  if (port != null) {
    port.write('A');
  }
}
void ServerState(int theValue) {

}
/***
 Functions related to communication with php 
 ***/
private boolean insertWindowDataToServer(String window_id, int windowState){
  String url = getWindowInsertionURL(window_id, windowState);
  println(url);
  if (url != null) {
    String[] lines = loadStrings(url);
    //println(lines);
    return true;
  }
  return false;
}

private String getWindowInsertionURL(String window_id, int windowState){
  String url = null;
  StringBuilder sb = new StringBuilder();
  sb.append(URL_updateWindowState);
  sb.append("?window_id=");
  sb.append(window_id);
  sb.append("&state=");
  sb.append(windowState);
  //sb.append("&location_id=")
  //sb.append(location_id)
  url = sb.toString();
  return url;
}

/***
 Functions related to config file 
 ***/
private void getSettings() {
  mPortName = getSettingFromConfigFile(dataPath("config.txt"));
  mHostName = getSettingFromConfigFile(dataPath("hostname.txt"));
  URL = mHostName + URL;
  URL_updateWindowState = mHostName + URL_updateWindowState;
}

private String getSettingFromConfigFile(String fileName) {
  String name = null;
  try {
    BufferedReader reader = createReader(fileName) ; 
    name = (reader.readLine());
  }
  catch(Exception e) {
  }
  //println("config port is " + name);
  return name;
}
void utterWindSound(boolean windowOpen){
  float currentVolume = player.getGain();
  //print(""+currentVolume+"\n");
  if(isWindowOpenTimeMatched() == true){
     player.pause();
  }
  else{
    if(windowOpen){
      if(!player.isPlaying())
        player.loop();
      player.shiftGain(currentVolume, 20, 1000);
    }
      
     else if(!windowOpen && player.isPlaying()){
      player.shiftGain(currentVolume, -20, 1000);
      if(currentVolume <= -16.0)
        player.pause();
    }
    //println(currentVolume);
  }
}
/***
 Functions for tool
 ***/
public static String getMacAddress(String ipAddr) throws UnknownHostException, SocketException {
  InetAddress addr = InetAddress.getByName(ipAddr);
  NetworkInterface ni = NetworkInterface.getByInetAddress(addr);
  if (ni == null)
    return null;

  byte[] mac = ni.getHardwareAddress();
  if (mac == null)
    return null;

  StringBuilder sb = new StringBuilder(18);
  for (byte b : mac) {
    if (sb.length() > 0) {
      sb.append(':');
    }
    sb.append(String.format("%02x", b));
  }
  return sb.toString();
}
