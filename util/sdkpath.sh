#!/bin/bash
# In order to use ESPTerm's download feature, your esp-open-sdk must be in
# your PATH. It is not enough to just add the SDK to your .bashrc, that may
# work when launching espterm from the terminal, but it certainly won't as
# soon as you try to launch it from your desktop's applications menu.
SDK_PATH=/opt/esp-open-sdk/xtensa-lx106-elf/bin
PROFILE=/etc/profile.d/espterm.sh

# Abort if not run as root
if [ $(id -u) -ne 0 ]
then
	echo "This script must be run as root. Aborting."
	exit 1
fi

read -e -p "[Path of esp-open-sdk binaries]: " -i $SDK_PATH SDK_PATH

echo "#/bin/bash" > $PROFILE
echo "export PATH=$SDK_PATH:\$PATH" >> $PROFILE
chmod +x $PROFILE

echo "$SDK_PATH has been permanently added to your PATH variable."
echo "Please log out and log back in to make the changes come into effect."
