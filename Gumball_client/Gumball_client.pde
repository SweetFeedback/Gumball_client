import processing.serial.*;
import processing.video.*;
import org.json.*;
import controlP5.*;
import ddf.minim.*;
import guru.ttslib.*;
import bluetoothDesktop.*;
import java.net.URLEncoder;
import java.io.UnsupportedEncodingException;
import gab.opencv.*;
import java.awt.Rectangle;
import java.awt.Frame;

private static final float GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE = 60;
private static final int DELAY_GIVE_FEEDBACK = 20;

private static boolean DEBUG = true;
private static int mDeviceId;
private static Serial mPort =null;
private static String mPortName = null;

private static String URL = "sensor_log/insert";
private static String URL_window = "window_log/insert";
private static String URL_getFeedback = "get_feedback";
private static String URL_updateFeedback = "update_feedback";
private static String URL_updateBlueTooth = "bluetooth_around";
private static String URL_updatePeopleAround = "";


private String mHostName = null;
private String inBuffer = null;
private boolean[] candySound = new boolean[]{true, false};
private boolean silentFlag = false;
private int bootError = 0; // 0: ok, 1: open port error, 2: server string error


int WIDTH = 400;
int HEIGHT = 200;
int FULL_WIDTH = 370;
int FULL_HEIGTH = 480;
int TEXT_HEIGHT = HEIGHT/2+40;
int margin_width = 10;
int margin_height = TEXT_HEIGHT + 10;
int cnt = 0;
int FRAME_RATE = 5;
int uploadSensorCounter = 0;

PFont Font01;
PFont metaBold;
Minim minim;
AudioPlayer player;
ControlP5 cp5;
CheckBox checkbox1, checkbox2;

Button settingDoneBtn;
DropdownList deviceDropDownList;
Textfield hostTextfield;
Boolean isSettingDone = false;

private TTS tts; // Text to speech object

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
  frameRate(FRAME_RATE);
  //frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
  
  //getSettings();
  
  setupSettingControlElement();
  
  minim = new Minim (this);
  player = minim.loadFile ("../audio/wind.wav");
  
  // Text to speech
  tts = new TTS();  
}

void draw() {
  background(128);
  
  
  if(isSettingDone) {
    setMessageText();
    if(uploadSensorCounter % (3 * FRAME_RATE) == 0) {
      handleSensorData();
      uploadSensorCounter = 0;
    }
    uploadSensorCounter++;
  }

}

void handleSensorData() {
  if (bootError == 1) {
    return;
  }
  
  String tmpBuffer = null;
  while (mPort.available() > 0) {
    tmpBuffer = mPort.readStringUntil('\n');
    if (tmpBuffer == null) {
      break;
    }
    
  }
  if(mPort != null) {
    if (tmpBuffer != null) {
      tmpBuffer = trim(tmpBuffer);
      //println(tmpBuffer);
      inBuffer = tmpBuffer;
      insertDataToServer(tmpBuffer);
    }
    if (bootError == 0) {
      askForSensorData(mPort);
    } else {
      mPort.write('z');
      //println("only establish contact");
    }
  }
}

void stop() {
  // always close Minim audio classes when you are done with them
  player.pause();
  minim.stop();
  super.stop();
}

void dispose() {
  if(mPort != null) {
    mPort.clear();
    mPort.stop();
  }
  super.dispose();
}

void setupSettingControlElement() {
  cp5 = new ControlP5(this);
  
  deviceDropDownList = cp5.addDropdownList("device-port")
    .setPosition(125, 20)
    .setSize(150, 50)
    ;
  deviceDropDownList.addItems(Serial.list());
  
  settingDoneBtn = cp5.addButton("OK")
     .setPosition(150, 150)
     .setSize(60,20)
     ;
  hostTextfield = cp5.addTextfield("Host")
    .setPosition(125, 90)
    .setSize(150, 10)
    .setText("http://209.129.244.24:1234/")
    .setFocus(true);
  
}

void OK() {
  int deviceIdx = (int)deviceDropDownList.getValue();
  String portName = Serial.list()[deviceIdx];
  String hostName = hostTextfield.getText();
  settingDoneBtn.remove();
  deviceDropDownList.remove();
  hostTextfield.remove();
  
  setupControlElement();
  
  getSettings(portName, hostName);
  println(portName + " " + hostName);
  
  isSettingDone = true;
}

void setupControlElement() {
  //cp5 = new ControlP5(this);
  /*checkbox1 = cp5.addCheckBox("checkBox1").setPosition(10, HEIGHT/2+20)
  .setColorForeground(color(120))
  .setColorActive(color(255))
  .setColorLabel(color(255))
  .setSize(10, 10)
  .addItem("No candy", 0);*/
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
  
  // drop down list
  if(theEvent.isGroup()) {
    int index = (int)theEvent.getGroup().getValue();
    if(index >= 0 && index < Serial.list().length) {
      println(Serial.list()[index]);
    }
  }
  
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


void setMessageText() {
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
    text("Device ID: " + mDeviceId, 10, HEIGHT/4 - 25); 
    text("Sensor Data:", 10, HEIGHT/4);
    text("S(dB), Li, T, IR, Win", 10, HEIGHT/4 + 25);
    if (inBuffer != null) {
      text(inBuffer, 8, height/2);      
    }
    if(!silentFlag) {
      askIfICanGetFeedback();
    }
  }
}


/***
 Functions related to port 
 ***/
private void portOpen(String name) {
  if (name != "") {
    mPort = new Serial(this, name, 9600);
    /*
    mPort.clear();
    // read bytes into a buffer until you get a linefeed (ASCII 10):
    mPort.bufferUntil('\n');
    */
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
private void askForDeviceId(Serial port) {
  if (port != null) {
    port.write('E');
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
  println(input);
  println(url);
  println(url_window);
  if (url != null && bootError == 0) {
    String[] lines = loadStrings(url);
  }
  if (url_window != null && bootError == 0) {
    String[] lines_window = loadStrings(url_window);
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
    sb.append("&state=");
    sb.append(window);
    url = sb.toString();  
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
    String[] rawResults = loadStrings(URL_getFeedback + "?device_id=" + mDeviceId);
    
    if (rawResults.length > 0) {
      String rawResult = join(rawResults, "");
      org.json.JSONObject resultObject = new org.json.JSONObject(rawResult);
      org.json.JSONArray feedbackArray = resultObject.getJSONArray("data");
      
      if (feedbackArray.length() > 0) {
        org.json.JSONObject target_feedback = feedbackArray.getJSONObject(0);
        if(DEBUG) {
          println(target_feedback);
        }
        int application_id = target_feedback.getInt("application_id");
        String type = target_feedback.getString("feedback_type");
        String description = target_feedback.getString("feedback_description");
        if (type.equals("positive")) {
          if(DEBUG) {
            println("give candy");
          }
          //if(candySound[0])
          askForCandy(mPort);
          //if(candySound[1])
          askForSound(mPort);
          speak(description);
        }else if(type.equals("sound")) {
          if(candySound[1]) askForSound(mPort);
        }else if(type.equals("saying")) {
          if(application_id == 9){
            speak("oh");
          }
          else if(application_id == 10){
            askForNegative(mPort);
            speak("ummm");
          }
        } else {
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
private void getSettings(String portName, String hostName) {
  println("setting");
  processing.data.XML xml;
  xml = loadXML(dataPath("config.xml"));
  mDeviceId = xml.getChild("device_id").getIntContent();
  
  mPortName = portName;
  mHostName = hostName;
  //mPortName = xml.getChild("port").getContent();
  //mHostName = xml.getChild("host").getContent();
  
  portOpen(mPortName);
  if(mPort == null|| mPort.output == null){
    bootError = 1;
    println("Port Unavailable");
  }
  /*
  if(bootError == 0 && loadStrings(mHostName) == null){
    bootError = 2;
    println("Server Unavailable");
  }
  */
  
  URL = mHostName + URL;
  URL_window = mHostName + URL_window;
  URL_getFeedback = mHostName + URL_getFeedback;
  URL_updateFeedback = mHostName + URL_updateFeedback;
  URL_updateBlueTooth = mHostName + URL_updateBlueTooth;
  URL_updatePeopleAround = mHostName + URL_updatePeopleAround;

  String tmpBuffer = null;
  while (true) {
    println("delay");
    delay(500);
  //while (mPort.available() > 0) {
    tmpBuffer = mPort.readStringUntil('\n');
    if (tmpBuffer == null) {
      continue;
    }
    print("establishContact: ");
    print(tmpBuffer);
    if(!tmpBuffer.startsWith("deviceID:")) {
      print("continue");
      delay(500);
      continue;
    }
    
    if (tmpBuffer == null) {
      continue;
    }
    String[] tokens = tmpBuffer.split(":");
    println(tokens[1].trim());
    mDeviceId = Integer.parseInt(tokens[1].trim());
    print("deviceid: " );
    println(mDeviceId);
    break;
  }
  askForSensorData(mPort);
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
 Text to Speech
 ***/
private void speak(String content) {
  tts.speak(content);
}
