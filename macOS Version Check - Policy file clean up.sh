#!/bin/zsh --no-rcs

:<<ABOUT_THIS_SCRIPT
----------------------------------------------------------------------------------------------------------------------------------------
Checks if the current installed macOS version matches the required version.

If the current installed macOS is equal to or greater than the required version
all macOS update prompt policy files are deleted.

Some of the policy files listed are older files from previous versions of the macOS update prompt script.
Edit the policyFiles variable to include the file paths that you need to be deleted. This script can be used in a Jamf policy
that runs at startup or at check-in after a Mac has been updated to the required macOS version.

Parameters: 
4 - Major macOS version
5 - Minor macOS version

VERSION 3

7/31/2025 - Howie Canterbury
----------------------------------------------------------------------------------------------------------------------------------------
ABOUT_THIS_SCRIPT

# Get current macOS version
echo "Checking current installed macOS"
osVersion=$(/usr/bin/sw_vers -productVersion)
osMajor=$(echo "$osVersion" | awk -F. '{print $1}')
osMinor=$(echo "$osVersion" | awk -F. '{print $2}')

# Read required version from Jamf Pro parameters
reqosMajor="$4"
reqosMinor="$5"
reqOS="${reqosMajor}.${reqosMinor}"

echo "Required macOS version is ${reqOS}"
echo "Current installed macOS version is ${osMajor}.${osMinor}"

# Files to delete if update is successful
# These files were created by the "macOS Update Prompt with Swift Dialog" script.
# Check the update prompt script for files that will be created and list them in this variable for removal.
policyFiles=(
	"/usr/local/Management/com.CompanyName.macOSUpdateDeferral.plist"
	"/usr/local/Management/UserCanceledmacOSUpdate"
	"/Library/LaunchDaemons/com.CompanyName.macOSUpdate.plist"
	"/usr/local/Management/macOSUpdateTrigger.sh"
	"/usr/local/Management/Defer_Check.sh"
	"/Library/Scripts/Defer_Check.sh"
	"/private/var/log/macOS-Software-Update.log"
	"/private/var/log/MULaunchD.log"
	"/private/var/log/MULaunchDError.log"
)

# Function to unload the launch daemon
checkLaunchd() {
	# Unload launch daemon if running
	if [[ $(/bin/launchctl list | grep com.CompanyName.macOSUpdate) ]]; then
		echo "Launch daemon running. Unloading..."
		/bin/launchctl remove com.CompanyName.macOSUpdate
	fi
}

# Compare versions and delete policy files if macOS has been updated
if [[ $osMajor -gt $reqosMajor ]] || { [[ $osMajor -eq $reqosMajor ]] && [[ $osMinor -ge $reqosMinor ]]; }; then
	echo "macOS has been updated"
	checkLaunchd
	
	found_any=0
	
	for file in "${policyFiles[@]}"; do
		if [[ -f "$file" ]]; then
			echo "Found file at "$file". Deleting..."
			rm "$file"
			found_any=1
		fi
	done
	if [[ $found_any -eq 0 ]]; then
		echo "No policy files found"
	fi
else
	echo "macOS has not been updated"
fi