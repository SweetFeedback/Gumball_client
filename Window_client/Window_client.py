#!/usr/bin/env python
""" generated source for module Window_client """

class Window_client():
    """ generated source for class Window_client """
    mWindowDeviceId = None
    mPort = None
    mPortName = None
    DATA_PATH = "./data"
    URL = "php/insertSensorValueToDbNew.php"
    URL_updateWindowState = "php/insertExtendedWindowState.php"
    mHostName = None
    inBuffer = None
    bootError = 0
    prevWindowStates = []
    WIDTH = 360
    HEIGHT = 200
    FULL_WIDTH = 370
    FULL_HEIGTH = 480
    TEXT_HEIGHT = HEIGHT / 2 + 40
    margin_width = 10
    margin_height = TEXT_HEIGHT + 10
    windowIdList = []
    Font01 = PFont()
    metaBold = PFont()

    # 
    #  Main Functions
    #  
    def setup(self):
        """ generated source for method setup """
        #size(self.WIDTH, self.HEIGHT)
        # PFont f = createFont("Arial", 20, true);
        # textFont(f);
        # PFont metaBold;
        #self.metaBold = loadFont("SansSerif-48.vlw")
        #self.Font01 = loadFont("SansSerif-48.vlw")
        #textFont(self.metaBold, 24)
        # frameRate(GLOBAL_FRAMERATE_FOR_GUMBALL_MACHINE);
        getSettings()
        is_exception_rasied = False
        try:
            portOpen(self.mPortName)
            is_exception_rasied = False
        except Exception as e:
            is_exception_rasied = True
        println("port_in_use exception:" + is_exception_rasied)
        if self.mPort == None or self.mPort.output == None:
            self.bootError = 1
        if self.bootError == 0 and loadStrings(self.mHostName) == None:
            self.bootError = 2

    def draw(self):
        """ generated source for method draw """
        background(128)
        if self.bootError > 0:
            if self.bootError==1:
                text("Cannot open port: ", 10, self.HEIGHT / 4 - 20)
                text(self.mPortName, 10, self.HEIGHT / 4 + 10)
            elif self.bootError==2:
                text("Cannot connect server: ", 10, self.HEIGHT / 4 - 20)
                text(self.mHostName, 10, self.HEIGHT / 4 + 10, 300, 24)
            else:
                text("Unknown boot error", 10, self.HEIGHT / 4 - 20)
        else:
            text("windows State Data:", 10, self.HEIGHT / 4 - 20)
            text("S(dB), Li, T, IR, Win", 10, self.HEIGHT / 4 + 10)
            if self.inBuffer != None:
                text(self.inBuffer, 8, height / 2 - 10)

    # public void serialEvent(Serial myPort) {
    #   String tmpBuffer = myPort.readStringUntil('\n');
    #   if (tmpBuffer != null) {
    #     tmpBuffer = trim(tmpBuffer);
    # println(tmpBuffer);
    #     inBuffer = tmpBuffer;
    #     String[] splited_data = tmpBuffer.split(",");
    #     if (splited_data != null && !(splited_data[0] == "-1")){
    #         for(int i = 0; i < splited_data.length; i++){
    #           int newWindowState = Integer.parseInt(splited_data[i]);
    #           if(newWindowState != prevWindowStates[i]){
    #             prevWindowStates[i] = newWindowState; 
    #             insertWindowDataToServer(String.valueOf(windowIdList[i]), newWindowState);
    #           }
    #         }      
    #     }
    # assert(splited_data.length == windowIdList.length);
    #   }
    #   if(bootError == 0) {
    #     askForWindowStateData(myPort);
    #   }else{
    #     myPort.write('z');
    # println("only establish contact");
    #   }
    # }
    def dispose(self):
        """ generated source for method dispose """
        self.mPort.clear()
        self.mPort.stop()
        super(Window_client, self).dispose()

    # 
    #  Functions related to port 
    # private void portOpen(String name) throws gnu.io.PortInUseException{
    #   if (name != "") {
    #     mPort = new Serial(this, name, 9600);
    #     mPort.clear();
    #  read bytes into a buffer until you get a linefeed (ASCII 10):
    #     mPort.bufferUntil('\n');
    #   }
    # }
    # 
    def setWindowIdList(self, windowDeviceIdStr):
        """ generated source for method setWindowIdList """
        splited_data = windowDeviceIdStr.split(",")
        self.windowIdList = [None]*
        self.prevWindowStates = [None]*
        i = 0
        while len(splited_data):
            self.windowIdList[i] = Integer.parseInt(splited_data[i])
            self.prevWindowStates[i] = -1
            i += 1

    def askForWindowStateData(self, port):
        """ generated source for method askForWindowStateData """
        if port != None:
            port.write('B')

    def ServerState(self, theValue):
        """ generated source for method ServerState """

    # 
    #  Functions related to communication with php 
    #  
    def insertWindowDataToServer(self, window_id, windowState):
        """ generated source for method insertWindowDataToServer """
        url = getWindowInsertionURL(window_id, windowState)
        println(url)
        if url != None:
            # println(lines);
            return True
        return False

    def getWindowInsertionURL(self, window_id, windowState):
        """ generated source for method getWindowInsertionURL """
        url = None
        sb = StringBuilder()
        sb.append(self.URL_updateWindowState)
        sb.append("?window_id=")
        sb.append(window_id)
        sb.append("&state=")
        sb.append(windowState)
        # sb.append("&location_id=")
        # sb.append(location_id)
        url = sb.__str__()
        return url

    # 
    #  Functions related to config file 
    #  
    def dataPath(self, s):
        return DATA_PATH + s

    def getSettings(self):
        """ generated source for method getSettings """
        self.mPortName = getSettingFromConfigFile(dataPath("config.txt"))
        self.mHostName = getSettingFromConfigFile(dataPath("hostname.txt"))
        self.mWindowDeviceId = getSettingFromConfigFile(dataPath("deviceId.txt"))
        self.setWindowIdList(self.mWindowDeviceId)
        self.URL = self.mHostName + self.URL
        self.URL_updateWindowState = self.mHostName + self.URL_updateWindowState

    def getSettingFromConfigFile(self, fileName):
        """ generated source for method getSettingFromConfigFile """
        name = None
        try:
            name = (reader.readLine())
        except Exception as e:
            pass
        # println("config port is " + name);
        return name

    # 
    #  Functions for tool
    #  
    @classmethod
    def getMacAddress(cls, ipAddr):
        """ generated source for method getMacAddress """
        addr = InetAddress.getByName(ipAddr)
        ni = NetworkInterface.getByInetAddress(addr)
        if ni == None:
            return None
        mac = ni.getHardwareAddress()
        if mac == None:
            return None
        sb = StringBuilder(18)
        for b in mac:
            if 0 > len(sb):
                sb.append(':')
            sb.append("{:02x}".format(b))
        return sb.__str__()

if __name__ == '__main__':
    Window_client.setup()

