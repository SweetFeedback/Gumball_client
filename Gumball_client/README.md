#Gumball_client
==============

####processing.org code 

###Installation steps.

1. Download the client application code directory. Two ways to install these packages:

	Option 1. 
	
		Pull the code if you know how to use "git":http://git-scm.com/downloads@git pull https://github.com/louisccc/GumballClient.git@
	
	Option 2. 
	
		Download the whole "*master.zip*":https://github.com/louisccc/Gumball_client/archive/master.zip

2. Copy the libraries directory into your sketch folder.
	
		a. org.json
		b. controlP5
		c. ttslib (http://www.local-guru.net/blog/pages/ttslib)
			If you are using Mac, you will be /Documents/Processing/libraries
		d. Desktopbluetooth (http://www.extrapixel.ch/processing/bluetoothDesktop/)
			If your getting errors about the "avetanaBT.jar", just delete that file from the library folder.
		e. OpenCV (http://urbanhonking.com/ideasfordozens/2013/07/10/announcing-opencv-for-processing/)
			When running on the Mac, make sure you have Processing set to 64-bit mode in the Preferences.

3. Modify the config file setting under the directory *"data/"*
		
	* Rename the file *"config.txt.template"* to *"config.txt"* With content **[The port name of your gumball machine device]**
		
			For Windows, you can check the port name of your device from *"settings->device manager"*
			[screenshot]
			For MaxOS, you can check the port name of your device by command,
			@ls /dev/tty.usbmodem*@ 
			For Linux, you can check the port name of your device by command, 
			@dmesg | grep "/dev"@ by unplugging the device and plug it again.
		
		
	* Rename the file **"deviceId.txt.template"** to **"deviceId.txt"** With content @[The device id you specify]@
	* Rename the file **"hostname.txt.template"** to **"hostname.txt"** With content **http://209.129.244.24:1234/**

4. Open the application under the directory that is suitable for your system *e.g.* for linux 32-bit user, you choose the application under the directory *"application.linux32"*