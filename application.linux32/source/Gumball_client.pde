import processing.serial.*;
import org.json.*;

private static final float GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE = 5;
private static final int DELAY_GIVE_FEEDBACK = 20;

private static int mDeviceId;
private static Serial mPort =null;
private static String mPortName = null;

private static String URL = "php/insertSensorValueToDbNew.php";
private static String URL_getFeedback = "php/getFeedbackStatus.php";
private static String URL_updateFeedback = "php/updateFeedback.php";

private String mHostName = null;
String inBuffer = null;

/***
 Main Functions
 ***/
void setup() {
  size(350, 200);
  PFont f = createFont("Arial", 20, true);
  textFont(f);
  //frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
  getSettings();
  portOpen(mPortName);
}

void draw() {
  background(128);
  text("Data from gumball Machine", 10, height/2 - 20);
  if (inBuffer != null) {
    text(inBuffer, 10, height/2);
  }
  askIfICanGetFeedback();
}

void serialEvent(Serial myPort) {
  /**/
  String tmpBuffer = myPort.readStringUntil('\n');
  if (tmpBuffer != null) {
    tmpBuffer = trim(tmpBuffer);
    //println(tmpBuffer);
    inBuffer = tmpBuffer;
    insertDataToServer(tmpBuffer);
  }
  askForSensorData(myPort);
}

/***
 Functions related to port 
 ***/
private void portOpen(String name) {
  if (name != "") {
    mPort = new Serial(this, name, 9600);
    // read bytes into a buffer until you get a linefeed (ASCII 10):
    mPort.bufferUntil('\n');
  }
}
private void askForSensorData(Serial port) {
  if (port != null) {
    port.write('B');
  }
}
private void askForCandy(Serial port) {
  if (port != null) {
    port.write('A');
  }
}
private void askForNegative(Serial port) {
  if (port != null) {
    port.write('C');
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
    sb.append("?d_id=");
    sb.append(mDeviceId);
    sb.append("&s_lv=");
    sb.append(sound);
    sb.append("&l_lv=");
    sb.append(light);
    sb.append("&tem=");
    sb.append(temp);
    sb.append("&p=");
    if(people != null) {
      sb.append("&p=");
      sb.append(people);
    }
    if(window != null) {
      sb.append("&w=");
      sb.append(window);
    }
    url = sb.toString();  
    //println(url);
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
    //text("Server unavailable: ask feedback", 10, height/2 + 40);
    println(e);
  }
}

/***
 Functions related to config file 
 ***/
private void getSettings() {
  mPortName = getSettingFromConfigFile(dataPath("config.txt"));
  mHostName = getSettingFromConfigFile(dataPath("hostname.txt"));
  mDeviceId = Integer.parseInt(getSettingFromConfigFile(dataPath("deviceId.txt")));
  URL = mHostName + URL;
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
