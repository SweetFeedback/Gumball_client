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
int[] windowIdList;
PFont Font01;
PFont metaBold;
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
  boolean is_exception_rasied = false;
  try{
    portOpen(mPortName);
    is_exception_rasied = false;
  }catch(Exception e){
    is_exception_rasied = true;
  }

  println("port_in_use exception:"+is_exception_rasied);
  if(mPort == null|| mPort.output == null){
    bootError = 1;
  }

  if(bootError == 0 && loadStrings(mHostName) == null){
    bootError = 2;
  }
  

  
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
    //println(tmpBuffer);
    inBuffer = tmpBuffer;
    String[] splited_data = tmpBuffer.split(",");
    if (splited_data != null && !(splited_data[0].equals("-1"))){
        for(int i = 0; i < splited_data.length; i++){
          int newWindowState = Integer.parseInt(splited_data[i]);
          if(newWindowState != prevWindowStates[i]){
            prevWindowStates[i] = newWindowState; 
            insertWindowDataToServer(String.valueOf(windowIdList[i]), newWindowState);
          }
          
        }      

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


/***
 Functions related to port 
 ***/
private void portOpen(String name) throws gnu.io.PortInUseException{
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
  mWindowDeviceId = getSettingFromConfigFile(dataPath("deviceId.txt"));
  setWindowIdList(mWindowDeviceId);
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
