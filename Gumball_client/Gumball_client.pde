import processing.serial.*;
import org.json.*;
import controlP5.*;
import ddf.minim.*;
import guru.ttslib.*;
import bluetoothDesktop.*;

private static final float GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE = 5;
private static final int DELAY_GIVE_FEEDBACK = 20;

private static boolean DEBUG = true;
private static int mDeviceId;
private static Serial mPort =null;
private static String mPortName = null;

private static String URL = "sensor_log/insert";
private static String URL_window = "window_log/insert";
private static String URL_getFeedback = "get_feedback";
private static String URL_updateFeedback = "update_feedback";

private String mHostName = "http://127.0.0.1:1234/";
private String inBuffer = null;
private boolean[] candySound = new boolean[]{true, false};
private boolean silentFlag = false;
private int bootError = 0; // 0: ok, 1: open port error, 2: server string error

int WIDTH = 360;
int HEIGHT = 400;
int FULL_WIDTH = 370;
int FULL_HEIGTH = 480;
int TEXT_HEIGHT = HEIGHT/2+40;
int margin_width = 10;
int margin_height = TEXT_HEIGHT + 10;
int cnt = 0;

PFont Font01;
PFont metaBold;
Minim minim;
AudioPlayer player;
ControlP5 cp5;
CheckBox checkbox1, checkbox2;

//Bluetooth bt;
int bluetoothTimer = 0;
Device[] devices = new Device[0];


private TTS tts; // Text to speech object

/***
 Main Functions
 ***/
void setup() {

  size(WIDTH, HEIGHT);
  metaBold = loadFont("SansSerif-48.vlw");
  Font01 = loadFont("SansSerif-48.vlw");
  textFont(metaBold, 24);
  frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
  getSettings();
  portOpen(mPortName);
  if(mPort == null|| mPort.output == null){
    bootError = 1;
    println("Port Unavailable");
  }
  setupControlElement();
  if(bootError == 0 && loadStrings(mHostName) == null){
    bootError = 2;
    println("Server Unavailable");
  }
  
  minim = new Minim (this);
  player = minim.loadFile ("../audio/wind.wav");
  
  // Text to speech
  tts = new TTS();
  
  
  // bluetooth init
//  try {
//    bt = new Bluetooth(this, Bluetooth.UUID_RFCOMM); // RFCOMM
//  
//    // Start a Service
//    bt.start("simpleService");
//  } 
//  catch (RuntimeException e) {
//    println("bluetooth off?");
//    println(e);
//  }
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
    text("Sensor Data:", 10, HEIGHT/4 - 20);
    text("S(dB), Li, T, IR, Win", 10, HEIGHT/4+10);
    if (inBuffer != null) {
      text(inBuffer, 8, height/2 - 10);      
    }
    if(!silentFlag) {
      askIfICanGetFeedback();
    }
  }
  String tmpBuffer = null;
  while(mPort.available() > 0){
    tmpBuffer = mPort.readStringUntil('\n');
    if (tmpBuffer != null) {
    }
    else{
      break;
    }
    
  }
  if (tmpBuffer != null) {
      tmpBuffer = trim(tmpBuffer);
      //println(tmpBuffer);
      inBuffer = tmpBuffer;
      insertDataToServer(tmpBuffer);
    }
  if(bootError == 0) {
    askForSensorData(mPort);
  }
  else{
    mPort.write('z');
      //println("only establish contact");
  }
 
}
void stop()
{
  // always close Minim audio classes when you are done with them
  player.pause();
  minim.stop();
  super.stop();
}
void dispose(){
  mPort.clear();
  mPort.stop();
  super.dispose();
}

void setupControlElement(){
  cp5 = new ControlP5(this);
  int h = HEIGHT/2 + 10;
  checkbox1 = cp5.addCheckBox("checkBox1").setPosition(10, h)
                .setColorForeground(color(120))
                .setColorActive(color(255))
                .setColorLabel(color(255))
                .setSize(20, 20)
                .setItemsPerRow(2)
                .setSpacingColumn(70)
                .setSpacingRow(20)
                .addItem("Candy", 0)
                .addItem("Sound", 0)
                ;
  checkbox2 = cp5.addCheckBox("checkBox2").setPosition(10, h+30)
                .setColorForeground(color(120))
                .setColorActive(color(255))
                .setColorLabel(color(255))
                .setSize(20, 20)
                .setSpacingColumn(70)
                .setSpacingRow(20)
                .addItem("Silence", 0)
                ;
  checkbox1.activate("Candy");
  cp5.addButton("GiveCandy")
     .setPosition(10,h + 60)
     .setSize(50,20)
     ;
  cp5.addButton("PosSound")
     .setPosition(80,h + 60)
     .setSize(48,20)
     ;
  cp5.addButton("NegSound")
     .setPosition(150,h + 60)
     .setSize(48,20)
     ;
  cp5.addButton("ServerState")
     .setPosition(220,h + 60)
     .setSize(60,20)
     ;
}

void controlEvent(ControlEvent theEvent) {
  CheckBox checkbox;
  if (theEvent.isFrom(checkbox1)) {
    checkbox = checkbox1;
    if(silentFlag){
      checkbox2.deactivateAll();
      silentFlag = false;
    }
    //print("got an event from "+checkbox.getName()+"\t\n");
    for (int i=0;i<checkbox.getArrayValue().length;i++) {
      if(checkbox.getArrayValue()[i] > 0){
        candySound[i] = true;
      }else{
        candySound[i] = false;
      }
    }
  } else if (theEvent.isFrom(checkbox2)) {
    checkbox = checkbox2;
    //print("got an event from "+checkbox.getName()+"\t\n");
    if (checkbox.getArrayValue()[0] > 0){
      if(!silentFlag){
        checkbox1.deactivateAll();
        silentFlag = true;
      }
    }
  }
}

/***
 Functions related to port 
 ***/
private void portOpen(String name) {
  if (name != "") {
    mPort = new Serial(this, name, 9600);
    mPort.clear();
    // read bytes into a buffer until you get a linefeed (ASCII 10):
    mPort.bufferUntil('\n');
  }
}
private void askForCandy(Serial port) {
  if (port != null) {
    port.write('A');
  }
}
private void askForSensorData(Serial port) {
  if (port != null) {
    port.write('B');
  }
}
private void askForNegative(Serial port) {
  if (port != null) {
    port.write('C');
  }
}
private void askForSound(Serial port) {
  if (port != null) {
    port.write('D');
  }
}
void GiveCandy(int theValue) {
  askForCandy(mPort);
}
void PosSound(int theValue) {
  askForSound(mPort);
}
void NegSound(int theValue) {
  askForNegative(mPort);
}
void ServerState(int theValue) {

}
/***
 Functions related to communication with php 
 ***/
private boolean insertDataToServer(String input) {
  String url = getInsertServerDatabaseURL(input);
  String url_window = getInsertWindowDatabaseURL(input);
  //println(url);
  if (url_window != null && bootError == 0) {
    String[] lines_sensor = loadStrings(url);
    println(lines_sensor);
  }
  if (url_window != null && bootError == 0) {
    String[] lines_window = loadStrings(url_window);
    println(lines_window);
  }
  return false;
}
private String getInsertWindowDatabaseURL(String input) {
  String url = null; 
  if(input != null) {
    String[] splited_data = input.split(",");
    if (splited_data == null || splited_data[0].equals("0")) return null;
    String sound, light, temp, people = null, window = null;
    switch(splited_data.length){
      case 5:
        people = splited_data[3];
        window = splited_data[4];
      case 3:
        sound = splited_data[0];
        light = splited_data[1];
        temp = splited_data[2];
        break;
      default:
        return null;
    }
    StringBuilder sb = new StringBuilder();
    sb.append(URL_window);
    sb.append("?location_id=3");
    sb.append("&device_id=");
    sb.append(mDeviceId);
    //cnt++;
    sb.append("&state=");
    sb.append(window);
    url = sb.toString();  
    if(DEBUG) {
      //println(url);
    }
  }
  return url;
}
private String getInsertServerDatabaseURL(String input) {
  String url = null;
  if (input != null) {
    String[] splited_data = input.split(",");
    if (splited_data == null || splited_data[0].equals("0")) return null;
    String sound, light, temp, people = null, window = null;
    switch(splited_data.length){
      case 5:
        people = splited_data[3];
        window = splited_data[4];
      case 3:
        sound = splited_data[0];
        light = splited_data[1];
        temp = splited_data[2];
        break;
      default:
        return null;
    }
    StringBuilder sb = new StringBuilder();
    sb.append(URL);
    sb.append("?device_id=");
    sb.append(mDeviceId);
    sb.append("&sound_level=");
    sb.append(sound);
    sb.append("&temperature=");
    sb.append(temp);
    sb.append("&light_level=");
    sb.append(light);

    url = sb.toString();  
    if(DEBUG) {
      //println(url);
    }
  }
  return url;
}
void utterWindSound(boolean windowOpen){
  float currentVolume = player.getGain();
  print(""+currentVolume+"\n");
  if(windowOpen){
    if(!player.isPlaying())
      player.loop();
    player.shiftGain(currentVolume, 20, 1000);
  }
    
   else if(!windowOpen && player.isPlaying()){
    player.shiftGain(currentVolume, -20, 1000);
    if(currentVolume <= -20.0)
      player.pause();
  }
}

void askIfICanGetFeedback() {
  try {
    String[] feedbacks = loadStrings(URL_getFeedback + "?device_id=" + mDeviceId);
    if(DEBUG) {
      //println(feedbacks);
    }
    if (feedbacks.length > 0) {
      String feedbackString = join(feedbacks, "");
      org.json.JSONObject resultObject = new org.json.JSONObject(feedbackString);
      org.json.JSONArray a = resultObject.getJSONArray("data");
      
      if (a.length() > 0) {
        org.json.JSONObject target_feedback = a.getJSONObject(0);
        if(DEBUG) {
          println(target_feedback);
        }
        int application_id = target_feedback.getInt("application_id");
        String type = target_feedback.getString("feedback_type");
        String description = target_feedback.getString("feedback_description");
        if (type.equals( "positive")) {
          if(DEBUG) {
            println("give candy");
          }
          //if(candySound[0])
          askForCandy(mPort);
          //if(candySound[1])
          askForSound(mPort);
          speak(description);
        }else if(type.equals("sound")){
          if(candySound[1]) askForSound(mPort);
        }else if(type.equals("saying")){
          if(application_id == 9){
            speak("oh");
          }
          else if(application_id == 10){
            askForNegative(mPort);
            speak("ummm");
          }
        }
        else {
          println("ask negative");
          //if(candySound[1])
          askForNegative(mPort);
          speak("ummm");
        }
        loadStrings(URL_updateFeedback + "?feedback_id=" + target_feedback.getInt("feedback_id"));
        delay(1000);
      }
    }
  }
  catch(Exception e) {
    text("Server unavailable: ask feedback", 10, height/2 + 40);
    println(e);
  }
}

/***
 Functions related to config file 
 ***/
private void getSettings() {
  mPortName = getSettingFromConfigFile(dataPath("config.txt"));
  //mHostName = getSettingFromConfigFile(dataPath("hostname.txt"));
  mDeviceId = Integer.parseInt(getSettingFromConfigFile(dataPath("deviceId.txt")));
  println(mPortName + " " + mHostName + " " + mDeviceId);
  URL = mHostName + URL;
  URL_window = mHostName + URL_window;
  URL_getFeedback = mHostName + URL_getFeedback;
  URL_updateFeedback = mHostName + URL_updateFeedback;
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

/***
 Bluetooth
 ***/
private void scanBluetooth() {
  
}


void deviceDiscoverEvent(Device d) {
  devices = (Device[])append(devices, d);
  println("found: " + d.name + " " + d.address);
}

void deviceDiscoveryCompleteEvent(Device[] d) {
  print("bluetooth discover completed: ");
  devices = d;
  if(d.length == 0) {
    println("found nothing");
  } else if(d.length > 0) {
    println(devices[0].name + " " + devices[0].address);
  }
}
 
 
/***
 Text to Speech
 ***/
private void speak(String content) {
  tts.speak(content);
}
