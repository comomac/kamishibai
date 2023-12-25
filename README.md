Kamishibai
=========================
> pronounce kami-shi-bye

Remote manga reader. Read manga anywhere using a web browser.  

Can read using iOS or Android tablet using swipe view. Can also read in desktop using keyboard shortcuts.

It remember where the manga is read upto, so you can resume reading with ease.

Support basic tagging in filenaming, please read file naming convention below. 

Settings can change image quality to conserve bandwidth.  

Zipped (CBZ) books are supported, please read file format below.  

Has username and password authentication to protect login.

I didn't touch the code for years, had a quick touchup to make sure it works. Found lots of old/bad code, but that was written in 2013, so please don't judge too harshly. Some day I will code and make it better when I have time.

Screenshots:
--------------------------  
### Directory view  
![Directory view](/images/view_dir.jpg)

### Tablet Browse view  
![Tablet Browse view](/images/view_browse.jpg)

### Reading  
![Reading](/images/reading.jpg)

### Settings  
![Settings](/images/settings.jpg)

Installation:
--------------------------
`gem install kamishibai`
  

Installation (extra info):
--------------------------

Mac OS X:  
1. Install [MacPorts](http://www.macports.org/)  
2. sudo port install ruby25 rb-rubygems gd2  
3. sudo gem install kamishibai
  
Linux (Ubuntu/Debian):  
1. sudo apt-get install ruby ruby-dev libgd-dev
2. sudo gem install kamishibai

Windows:
1. Install the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
2. Choose Ubuntu install
3. Follow instruction for Linux above

Access:
--------------------------
1. Run program   `kamishibai`
2. Open browser and type  `http://127.0.0.1:9999`  
3. Default username and password is admin/admin, please change it for security purpose.

Configuration:
--------------------------
Config file is written in JSON format. The config file will be located at ~/etc/kamishibai.conf. The config file can also manually selected by appending the config path after the program.  

There is also web configuration panel, goto http://host_ip:host_port/config to configure.


  
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
  
  
License:
--------------------------
BSD 3-clause
Mac Ma gitmac at runbox.com (C) 2013-2023 Copyright
