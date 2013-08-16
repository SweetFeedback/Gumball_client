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

//private static final float GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE = 60;
private static final int FRAME_RATE = 5;
private static final int SECOND_PER_UPLOAD_SENSOR = 5;
private static final int SECOND_PER_FACEDETECTION = 1;
private static final int SECOND_PER_ASK_FEEDBACK = 1;
int frame_counter = 0;
boolean spoken_flag = false;
int zero_faces_count = 0;
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
private static String URL_updatePeopleAround = "people_around";


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
int faces_count = 0;
PFont Font01;
PFont metaBold;
Minim minim;
AudioPlayer player;
ControlP5 cp5;
CheckBox checkbox1, checkbox2;

//Bluetooth bt;
int bluetoothTimer = 0;
Device[] devices = new Device[0];

Capture video;
Rectangle[] faces;
OpenCV opencv;


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
  frameRate(frameRate);
  //frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
  
  //getSettings();
  
  setupSettingControlElement();
  
  minim = new Minim (this);
  player = minim.loadFile ("../audio/wind.wav");
  
  // Text to speech
  tts = new TTS();
  
  
  // bluetooth init
//  try {
//    bt = new Bluetooth(this, Bluetooth.UUID_RFCOMM); // RFCOMM
//
//  // Start a Service
//    bt.start("simpleService");
//  } 
//  catch (RuntimeException e) {
//    println("bluetooth off?");
//    println(e);
//  }
  video = new Capture(this, 320, 480);
  opencv = new OpenCV(this, 320, 480);
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  
  // Start capturing the images from the camera
  video.start();
}

void captureEvent(Capture c) {
  c.read();
}

void draw() {
  background(128);
  if(isSettingDone) {
    setMessageText();
    
    if(frame_counter % (SECOND_PER_UPLOAD_SENSOR * FRAME_RATE) == 0) {
      handleSensorData();
    }
    
    if(frame_counter % (SECOND_PER_ASK_FEEDBACK * FRAME_RATE) == 0) {
      println("ASK FEEEDBACK");
      askIfICanGetFeedback();
    }
    
    if(frame_counter % (SECOND_PER_FACEDETECTION * FRAME_RATE) == 0) {
      faceDetection();
      
      if(faces.length > 0) {
        faces_count++;
        zero_faces_count = 0;
        if(faces_count > 3 && spoken_flag == false) {
          spoken_flag = true;
          uploadPeopleAroundAndGetProblem(faces.length);
        }
      } else if(faces.length == 0) {
        zero_faces_count++;
        
        // reset if no one appear in 15 frames
        if(zero_faces_count > 15) {
          println("reset spoken_flag");
          spoken_flag = false;
          zero_faces_count = 0;
          faces_count = 0;
        }
      }
    }
    
    if(frame_counter > 10000) {
      frame_counter = 0; // prevent overflow
    }
  }
  
  frame_counter++;
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

void faceDetection() {
  opencv.loadImage(video);
  //image(video, 0, 0);

  noFill();
  stroke(0, 255, 0);
  strokeWeight(3);
  faces = opencv.detect();
  println("found " + faces.length + " faces");

  for (int i = 0; i < faces.length; i++) {
    //println(faces[i].x + "," + faces[i].y);
    //rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
  }
}

void setupSettingControlElement() {
  cp5 = new ControlP5(this);
  
  deviceDropDownList = cp5.addDropdownList("device-port")
    .setPosition(10, 90)
    .setSize(200, 200)
    ;
  deviceDropDownList.addItems(Serial.list());
  deviceDropDownList.setIndex(0);
  
  settingDoneBtn = cp5.addButton("OK")
     .setPosition(150, 150)
     .setSize(60,20)
     ;
  hostTextfield = cp5.addTextfield("Host")
    .setPosition(10, 10)
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
    text("Sensor Data:", 10, HEIGHT/4 - 20);
    text("S(dB), Li, T, IR, Win", 10, HEIGHT/4+10);
    if (inBuffer != null) {
      text(inBuffer, 8, height/2 - 10);      
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



/***
 Functions related to communication with server 
 ***/

private boolean insertDataToServer(String input) {
  String url = getInsertServerDatabaseURL(input);
  //String url_window = getInsertWindowDatabaseURL(input);
  println(input);
  //println(url);
  //println(url_window);
  if (url != null && bootError == 0) {
    String[] lines = loadStrings(url);
  }
  //if (url_window != null && bootError == 0) {
  //  String[] lines_window = loadStrings(url_window);
  //}
  return false;
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
    if(window != null){
      sb.append("&window_state=");
      sb.append(window);
    }

    url = sb.toString();  
  }
  return url;
}


void uploadPeopleAroundAndGetProblem(int peopleNum) {
  speak("Save energy get reward");
  
  String url = URL_updatePeopleAround + "?device_id=" + mDeviceId + "&people_count=" + peopleNum;
  String[] lines = loadStrings(url);
  /*
  if(lines != null) {
    String rawResults = join(lines, "");
    println(rawResults);
    try{
      org.json.JSONObject resultObject = new org.json.JSONObject(rawResults);
      org.json.JSONObject problemJsonObject = resultObject.getJSONObject("problem");
      println(problemJsonObject);
      
      String description = problemJsonObject.getString("problem_desc");
      //delay(1000);
      if(description != null && spoken_flag == false) {
        spoken_flag = true;

        speak("Save energy get reward");

      }
    } catch(Exception e) {
      println(e);
    }
  }
  */
}


void askIfICanGetFeedback() {
  try {
    String[] rawResults = loadStrings(URL_getFeedback + "?device_id=" + mDeviceId);
    
    if (rawResults.length > 0) {
      String rawResult = join(rawResults, "");
      org.json.JSONObject resultObject = new org.json.JSONObject(rawResult);
      org.json.JSONArray feedbackArray = resultObject.getJSONArray("data");
      
      for(int i = 0; i < feedbackArray.length(); i++) {
      //if (feedbackArray.length() > 0) {
        org.json.JSONObject target_feedback = feedbackArray.getJSONObject(i);
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
            askForSound(mPort);
            String voice = getPositiveVoice();
            speak(voice);
          }
          else if(application_id == 10){
            askForNegative(mPort);
            String voice = getNegativeVoice();
            speak(voice);
          }
        } else {
          println("ask negative");
          //if(candySound[1])
          askForNegative(mPort);
          String voice = getNegativeVoice();
          speak(voice);
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
  String[] params = {"say", content};
  exec(params);
  delay(1000);
  //tts.speak(content);
}

private String getPositiveVoice() {
  String[] voices = {"Good", "Great", "Ya"};
  int index = (int)random(voices.length);
  return voices[index];
}

private String getNegativeVoice() {
  String[] voices = {"NO", "Uh", "Come on"};
  int index = (int)random(voices.length);
  return voices[index];
}
