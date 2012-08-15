import processing.serial.*;
import org.json.*;
import processing.video.*;
import com.google.zxing.*;
import java.awt.image.BufferedImage;

private static final float GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE = 5;
private static final int DELAY_GIVE_FEEDBACK = 20;

private static int mDeviceId;
private static Serial mPort =null;
private static String mPortName = null;

private static String URL = "php/insertSensorValueToDbNew.php";
private static String URL_getFeedback = "php/getFeedbackStatus.php";
private static String URL_updateFeedback = "php/updateFeedback.php";

Capture cam; //Set up the camera
com.google.zxing.Reader reader = new com.google.zxing.MultiFormatReader();

private String mHostName = null;
public static final String USERNAME = "username";
public static final String CANDYNUM = "candynum";
public static final String TASK = "task";
String inBuffer = null;
int WIDTH = 640;
int HEIGHT = 480;
int TEXT_HEIGHT = 60;

String lastResult = ""; //This is the last ISBN we acquired
PFont Font01;

PFont metaBold;
int candyNum = -1;
String username = null;
private final static int scanQRcodeStr = 1,userinfo = 2;
int sceneId = scanQRcodeStr;
long recordmillis = 0;
/* when sceneId = 1 -> QRscan
   when sceneId = 2 -> UserInfoPage  */
/***
 Main Functions
 ***/
 
void setup() {
  size(WIDTH, HEIGHT);
  //PFont f = createFont("Arial", 20, true);
  //textFont(f);
  PFont metaBold;
  metaBold = loadFont("SansSerif-48.vlw");
  Font01 = loadFont("HarlowSolid-24.vlw");
  textFont(metaBold, 36);
  cam = new Capture(this, WIDTH, HEIGHT);
  //frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
  getSettings();
  portOpen(mPortName);
}

void draw() {

  /*text("Data from gumball Machine", 10, height/2 - 20);
  if (inBuffer != null) {
    text(inBuffer, 10, height/2);
  }*/
  switch(sceneId) {
    case scanQRcodeStr:
      readStringFromQRcode();
      break;
    case userinfo:
      showUserInfo();
      break;
  }

}
void setRandomColor(){
  if(millis() - recordmillis > 500){
    fill(random(255), random(255), random(255));
    recordmillis = millis(); 
  }
}
void showUserInfo(){
  background(0);
  setRandomColor();
  textFont(Font01);
  Font01 = loadFont("Rockwell-ExtraBold-60.vlw");
  text("Welcome "+username, 20, 80);
  text("you can get "+candyNum+" round(s) of candies ", 20, 130);
}
void readStringFromQRcode(){
  background(250);
  fill(0, 0, 0);  
  text("scan the QR code here",HEIGHT/3-20, 48);

  Font01 = loadFont("Rockwell-ExtraBold-60.vlw");
  String resultStr = scanQRcode();
//  if(resultStr!=null && resultStr!= lastResult){
  if(resultStr!=null){
    Base64 base64 = new Base64();
    String decodeString = new String(base64.decode(resultStr));
    println(decodeString);
    JSONObject QRcodeInfo = new JSONObject(decodeString);
    if(QRcodeInfo.has(CANDYNUM) && QRcodeInfo.has(USERNAME)){
      candyNum = QRcodeInfo.getInt(CANDYNUM);
      username = QRcodeInfo.getString(USERNAME);
    }
    else{
      println("invalid key");
    }
    //sceneId = userinfo;
    (new candyThread(candyNum, 2000)).start();
    sceneId = userinfo;
    
    lastResult = resultStr;
  }
}
public class candyThread extends Thread{
  private int candyNum;
  private long waitingTime;
  public candyThread(int candyNum, long waitingTime){
    this.candyNum = candyNum;
    this.waitingTime = waitingTime;
  }
  public void run()
  {
  try{
      for(int i = 0; i < candyNum; i++) {
        println("candies come in three second");
        askForCandy(mPort);
        Thread.sleep(waitingTime);
      }
  }
  catch (Exception e) {
      e.printStackTrace();
    }
  
  sceneId = scanQRcodeStr;
  }

}
 
String scanQRcode(){
  if (cam.available() == true) {
    cam.read(); 
    image(cam, 0, TEXT_HEIGHT);
    try {
      //Create a bufferedimage
      BufferedImage buf = new BufferedImage(WIDTH, HEIGHT - TEXT_HEIGHT, 1); // last arg (1) is the same as TYPE_INT_RGB
      buf.getGraphics().drawImage(cam.getImage(), 0, 0, null);
      // Now test to see if it has a QR code embedded in it
      LuminanceSource source = new BufferedImageLuminanceSource(buf);
      BinaryBitmap bitmap = new BinaryBitmap(new HybridBinarizer(source)); 
      Result result = reader.decode(bitmap); 
      //Once we get the results, we can do some display
      if (result.getText() != null) {
        ResultPoint[] points = result.getResultPoints();
        //Draw some ellipses on at the control points
        for (int i = 0; i < points.length; i++) {
          fill(#ff8c00);
          ellipse(points[i].getX(), points[i].getY(), 20, 20);
          fill(#ff0000);
          text(i, points[i].getX(), points[i].getY());
        }
      
      }
      return result.getText();
    } 
    catch (Exception e) {
      // println(e.toString());
    }
  }
  return null;
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
