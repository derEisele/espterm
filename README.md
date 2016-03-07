# ESPTerm - ESP8266 Serial Port Terminal
## Screenshot
![Archlinux Screenshot](http://i.imgur.com/w6uJsND.png)

## Description
If you are using the ESP8266 with Linux as your development environment, you propably know the annoyances of manually pressing buttons or connecting jumpers just to get the SoC to boot from its flash chip, of using many different tools to flash your program and of AT commands that just don't work when entered because of some line ending problems. It doesn't have to be that way!
ESPTerm is a minimalistic, yet powerful serial port terminal for ESP8266 development in GNOME and other Linux desktop environments.
ESPTerm automatically sets up the ESP8266 so that it boots from the flash chip and has an option to automatically disconnect, flash your project to the ESP8266 and connect to it again in normal boot mode. No more switching between applications or manually placing jumpers required!

## Hardware setup
ESPTerm is compatible with [esptool](https://github.com/themadinventor/esptool)'s setup, using RTS and DTR to toggle CH_PD and GPIO0.

| **ESP8266 Pin** | **Serial Port Pin**   |
|-----------------|-----------------------|
| CH_PD           | RTS                   |
| GPIO0           | DTR                   |
| GPIO15          | GND / Low (directly)  |
| GPIO2           | VCC / High (Resistor) |
| TX (send)       | RX (receive)          |
| RX (receive)    | TX (send)             |

## Usage
* The switch on the top left connects / disconnects the serial port. It will also automatically use DTR / RTS to get the ESP8266 into flash boot mode when connecting.
* You can select the serial port and the baudrate using the two combo boxes at the bottom. ESPTerm supports many more baudrates than the selection that is listed, you can just type them in.
* The refresh button at the bottom refreshes the list of available serial ports.
* The CR LF button toggles between CR LF (`\r\n`) as line ending and just CR (`\r`)
* The down arrow on the top left can be used to automatically flash your project to the ESP8266. When first clicking it, a dialog will pop up that asks you for your project folder (the folder that your Makefile resides in). See section *esp-open-sdk Integration* for more information. You can choose a different project folder using the `Ctrl`+`Shift`+`O` shortcut.

### Shortcuts
* `F5`: Flash project, see *esp-open-sdk Integration* (= clicking flash button)
* `F6`: Open serial port and boot ESP8266 (= turning switch on)
* `F7`: Close serial port (= turning switch off)
* `Ctrl`+`Shift`+`L`: Clear terminal window
* `Ctrl`+`Shift`+`O`: Choose a different project folder
* `Ctrl`+`Shift`+`C`: Copy selected text in terminal to clipboard
* `Ctrl`+`Shift`+`V`: Paste text in clipboard to terminal

## Installation
### Preparation
ESPTerm requires GTK 3.16 or later!
#### Archlinux / Antergos (up to date)
* Dependencies: `# pacman -S vala pkg-config vte3 base-devel --needed`
* Add your user to the uucp group to access the serial port: `sudo usermod -a -G uucp $(whoami)`
* Either *log out and log back in* OR `su - $(whoami)`, then `export DISPLAY=:0` before running `espterm`

#### Ubuntu (15.10 or later)
* Dependencies: `# apt-get install valac libvte-2.91-dev gcc`
* Add your user to the dialout group to access the serial port: `sudo usermod -a -G dialout $(whoami)`
* Either *log out and log back in* OR `su - $(whoami)`, then `export DISPLAY=:0` before running `espterm`

#### Fedora (23 or later)
* Dependencies: `# dnf install vala glib2-devel vte291-devel gcc`
* Add your user to the dialout group to access the serial port: `sudo usermod -a -G dialout $(whoami)`
* Either *log out and log back in* OR `su - $(whoami)`, then `export DISPLAY=:0` before running `espterm`

### Compilation
* Download espterm somehow or `git clone https://github.com/Jeija/espterm.git`
* `cd espterm`
* `make`
* You can launch ESPTerm by calling `./espterm` or running `make run`
* If you want to install espterm system-wide: `# make install` (as root)

### esp-open-sdk Integration
#### PATH setup
If you want to use ESPTerm's download functionality you must make sure that your esp-open-sdk compiler setup is in your `PATH` variable. It is *not enough* to just add the compiler path to your .bashrc, you will need to add it to `/etc/profile.d/espterm.sh`, so that espterm also works when it was not started from your bash prompt. *Use the `util/sdkpath.sh` script to take care of the profile setup for you*, or alternatively
* Create `/etc/profile.d/espterm.sh`
* `chmod +x /etc/profile.d/espterm.sh`
* Add these lines to `/etc/profile.d/espterm.sh`, adapting the SDK path to your setup
```Bash
#/bin/bash
export PATH=/opt/esp-open-sdk/xtensa-lx106-elf/bin:$PATH
```

#### Makefile / Project setup
An example project for use with espterm is provided in `util/sampleproject`.

When clicking the flash button and choosing the project directory, espterm executes `make flash` in that directory. Therefore, your Makefile must provide a `flash` target that takes care of somehow uploading the code to the ESP8266. ESPTerm provides `PORT` as an environment variable that contains the currently selected port in the UI, e.g. `/dev/ttyUSB0`. You can make use of this feature by parsing that parameter in your Makefile and passing it on to e.g. esptool:
```Makefile
PORT ?= /dev/ttyUSB0 # If PORT is set as environment variable, use that value
```

## Implementation
ESPTerm is written in vala (and a tiny bit of C). `serial.vala` is completely independent of ESPTerm and may also be useful for other applications. If you want to use `serial.vala` for your application, but don't want to License it under the GPLv3, feel free to contact me and I may consider relicensing it to whatever your project uses.

## License
ESPTerm is licensed under the GPLv3, see the `LICENSE` file.
