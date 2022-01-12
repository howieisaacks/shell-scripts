#!/bin/sh

#Removes setting to display recent apps in the Dock

#Who is the current user?
currentuser=`/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }'`

#Change Dock setting to not show recent apps
/usr/bin/defaults write "/Users/$currentuser/Library/Preferences/com.apple.dock.plist" show-recents -bool false

#Change ownership of the Dock plist file to the current user.
chown $currentuser "/Users/$currentuser/Library/Preferences/com.apple.dock.plist"



#Created by Howie Isaacks | F1 Information Technologies | 11/12/2021