#!/bin/zsh

###Sets the computer name to the computer's serial number followed by the user's initials.

#Who is the current logged in user?
currentUser=`/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }'`
echo $currentUser

#What is the serial number of the computer?
serialNumber=$(system_profiler SPHardwareDataType | grep Serial | /usr/bin/awk '{ print $4 }')
echo $serialNumber

#Generate computer name. Get the user's initials and combine them with the serial number.
firstInitial=$(finger -s $currentUser | head -2 | tail -n 1 | awk '{print toupper ($2)}' | cut -c 1)
lastInitial=$(finger -s $currentUser | head -2 | tail -n 1 | awk '{print toupper ($3)}' | cut -c 1)

computerName=$"$serialNumber-$firstInitial$lastInitial"
echo $computerName

#Set the computer name and run an inventory.
/usr/local/jamf/bin/jamf setComputerName -name $computerName
/usr/local/jamf/bin/jamf recon

### Howie Isaacks | 3/28/23
