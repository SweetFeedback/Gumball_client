import processing.serial.*;
import org.json.*;

private static final float GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE = 5 ;
private static final int DELAY_GIVE_FEEDBACK=20;

private static int mDeviceId;
private static Serial mPort =null;
private static String mPortName = null;

private static String URL = "php/insertSensorValueToDbNew.php";
private static String URL_getFeedback = "php/getFeedbackStatus.php";
private static String URL_updateFeedback = "php/updateFeedback.php";

private String mHostName = null;

PFont f;
String inBuffer = null;


/***
 Main Functions
 ***/
void setup() {
  size(350, 400);
  f = createFont("Arial", 20, true);
  frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
  setting();
  portOpen(mPortName);
  URL = mHostName + URL;
  URL_getFeedback = mHostName + URL_getFeedback;
  URL_updateFeedback = mHostName + URL_updateFeedback;
}

void draw() {
  background(128);
  textFont(f);
  text("Data from gumball Machine", 10, height/2 - 20);
  if (inBuffer != null) {
    text(inBuffer, 10, height/2);
  }
  update();
}

void update() {
  if (mPort != null && mPortName != "") {
    askForSensorData(mPort);
    askIfICanGetFeedback();
  }
  else {
    // maybe try to open serial port.
  }
}

void serialEvent(Serial p) {
  String inBuffer2 = mPort.readStringUntil('\n');
  if (inBuffer2 != null) {
    //println(inBuffer);
    inBuffer = inBuffer2;
    insertDataToServer(inBuffer2);
  }
}

/***
 Functions related to port 
 ***/
private void portOpen(String name) {
  if (name != "") {
    mPort = new Serial(this, name, 9600);
    mPort.clear();
  }
}
private void askForSensorData(Serial port) {
  if (port != null) {
    port.write("B");
  }
}
private void askForCandy(Serial port) {
  if (port != null) {
    port.write("A");
  }
}
private void askForNegative(Serial port) {
  if (port != null) {
    port.write("C");
  }
}

/***
 Functions related to communication with php 
 ***/
private boolean insertDataToServer(String input) {
  String url = getInsertServerDatabaseURL(input);
  if (url != null) {
    String[] lines = loadStrings(url);
    //println(lines);
    return true;
  }
  return false;
}
private String getInsertServerDatabaseURL(String input) {
  String url = null;
  if (input != null) {
    String[] splited_data = input.split(",");
    if (splited_data.length != 5)
      return null;
    int id = mDeviceId;
    String sound = splited_data[0];
    String light = splited_data[1];
    String temp = splited_data[2];
    String people = "0";
    String window = "0";
    if (splited_data.length > 3) {
      people = splited_data[3];
      window = splited_data[4];
    }
    StringBuilder sb = new StringBuilder();
    sb.append(URL);
    sb.append("?d_id=");
    sb.append(id);
    sb.append("&s_lv=");
    sb.append(sound);
    sb.append("&l_lv=");
    sb.append(light);
    sb.append("&tem=");
    sb.append(temp);
    sb.append("&p=");
    sb.append(people);
    sb.append("&w=");
    sb.append(window);
    url = sb.toString();  
    //println(sb.toString());
  }
  return url;
}
void askIfICanGetFeedback() {
  try {
    String[] feedbacks = loadStrings(URL_getFeedback + "?device_id=" + mDeviceId);      
    if (feedbacks.length != 0) {
      //println(feedbacks);
      JSONArray a = new JSONArray(feedbacks[0]);
      if (a.length() != 0) {
        JSONObject target_feedback = a.getJSONObject(0);
        String type = target_feedback.getString("feedback_type");
        if (type.equals( "positive")) {
          askForCandy(mPort);
        }
        else {
          askForNegative(mPort);
        }
        loadStrings(URL_updateFeedback + "?id=" + target_feedback.getInt("feedback_id"));
      }
    }
  }
  catch(Exception e) {
  }
}

/***
 Functions related to config file 
 ***/
private void setting() {
  mPortName = getSettingFromConfigFile(dataPath("config.txt"));
  mHostName = getSettingFromConfigFile(dataPath("hostname.txt"));
  mDeviceId = Integer.parseInt(getSettingFromConfigFile(dataPath("deviceId.txt")));
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
public static String getMacAddress(String ipAddr)
throws UnknownHostException, SocketException {
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

