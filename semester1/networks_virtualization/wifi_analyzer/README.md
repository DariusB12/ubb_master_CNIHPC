# Commands to change the wifi adapter from `Managed` mode to `Monitor` mode
`ifconifg` to check is the wifi adapter is connected    
`iwconfig` to check the network adapter mode    

# Change from `Monitor` mode to `Managed` mode 
`ifconfig wlan0 down` to turn off the wifi adapter  
`iwconfig wlan0 mode managed` to change the mode    
`ifconfig wlan0 up` to turn on the wifi adapter    

# Change from `Managed` mode to `Monitor` mode
`ifconfig wlan0 down` to turn off the wifi adapter  
`iwconfig wlan0 mode monitor` to change the mode    
`ifconfig wlan0 up` to turn on the wifi adapter    

# The program should be run with sudo privileges from the terminal
`sudo python3 main.py`

# THe problem is that my network adapter doesn't support `Monitor` mode (integrated intel wifi adapter)
Because of that i will do the 3) requirement.   
The scapy library gives me an accurate view about the width of the channels used for a wifi network (not only the central one), but in order to use scapy i neet to put the `Monitor` mode  
Because i cannot do that, i will use pywifi, which gives me the central channel used, and the width i will suppose to be +-2 channels (20Mhz)   

# Run the porgram:
`sudo python3 wifi_analyzer.py`
`sudo python3  wifi_sniffer.py`     
Pentru sniffer payload http accesez site-ul http://grandshinyclearbirds.neverssl.com/online/ care e unsecure! si pot vedea payload      
`sudo python3 audit_tool.py`        