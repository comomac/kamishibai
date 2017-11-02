Kamishibai
=========================
> pronounce kami-shi-bye

Remote manga reader. Read manga anywhere using a web browser.

Update:
--------------------------  
Didn't touch the code for years, had a quick touchup to make sure it works. Found lots of old/bad code, but that was written in 2013, so please don't judge too harshly.

Installation:
--------------------------
Mac OS X:  
1. Install [MacPorts](http://www.macports.org/)  
2. sudo port install ruby19 rb-rubygems gd2  
3. sudo gem1.9 install kamishibai
  
Linux (Ubuntu/Debian):  
1. sudo apt-get install ruby1.9.1-full rubygems libgd2-xpm libgd2-xpm-dev  
2. sudo gem install kamishibai

Access:
--------------------------
Launch browser and type http://127.0.0.1:9999

Configuration:
--------------------------
Config file is written in JSON format. The config file will be located at ~/etc/kamishibai.conf. The config file can also manually selected by appending the config path after the program.  

There is also web configuration panel, goto http://<host>:<port>/config to configure.
  
Start:  
--------------------------
kamishibai [config_file.conf]
  
File Format:
--------------------------
Only CBZ is supported and it should be zero compressed zip file. This will reduce the burden on the system when reading as well as making the experience more responsive. The file name will determind how it will be organized by the program.

File naming convention:
--------------------------
Ideally, the CBZ file name should be in such format.  
  
(genre|meta data) [Author] Book Title Volume|chapter|v|ch 1.  
  
For example  
(Manga) [Yamada Taro] World of Sakura Volume 01.cbz  
(一般コミック) [山田太郎] 桜の世界 第01巻.cbz
  
  
Problem/Fix 1:
--------------------------
If the server is very slow to respond to requests. chances are that the Webrick is running with reverse lookup. Disable reverse lookup by editing  
/usr/lib/ruby/1.9.1/webrick/config.rb  
change  
":DoNotReverseLookup => nil,"  
to  
":DoNotReverseLookup => true,"
without the quotes.
  
  
Problem/Fix 3:
--------------------------  
The new 2.1.* version of GD2 cause breakage to the GD2-FFIJ, so downgrade the GD2 and stick to version 2.0.*. Until the fixes are released.  
  
Tested with:
--------------------------
Server:  
Mac OS X (10.8)  
Linux (Ubuntu 12.04)  

Client:  
Mac OS X 10.8 with Firefox 21, Chrome 27 and Safari 6  
iPad mini iOS6 with Safari and Chrome  
Nexus 7 with Chrome and Firefox  
  
  
License:
--------------------------
BSD 3-clause
Mac Ma gitmac at runbox.com (C) 2013 Copyright
