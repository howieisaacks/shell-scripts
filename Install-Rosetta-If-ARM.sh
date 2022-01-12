#!/bin/sh

#Checks if a Mac is Apple Silicon or Intel. Installs Rosetta if the Mac is Apple Silicon.

arch=$(/usr/bin/arch)
if [ "$arch" == "arm64" ]; then
    echo "Apple Silicon - Installing Rosetta"
    /usr/sbin/softwareupdate --install-rosetta --agree-to-license
elif [ "$arch" == "i386" ]; then
    echo "Intel - Skipping Rosetta"
else
    echo "Unknown Architecture"
fi

#Created by Howie Isaacks | F1 Information Technologies | 08/11/2021