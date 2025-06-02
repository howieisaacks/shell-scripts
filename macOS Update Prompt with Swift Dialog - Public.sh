#!/bin/zsh --no-rcs

# Activate set -x for debugging
#set -x

:<<ABOUT_THIS_SCRIPT
---------------------------
Uses Swift Dialog to alert users that A macOS Update is required.


Parameters: 
4 - macOS required version  5 - Release Notes  6 - Timer (in seconds)  7 - Deadline date seconds (epoch time)
8 - Required macOS major version  9 - Required macOS minor version  10 - URL or file path for Dialog icon

Use the "org" variable to specify your oganization name for the two launch daemons created by this script. The variable
may not work in the launch daemon creation functions. For these just replace the text manually.

Release notes: https://support.apple.com/en-us/121011

For deadline date epoch time value run: 
date -jf "%Y-%m-%d %H:%M:%S" "2024-07-21 11:00:00" +%s  <--change the year-month-day hour-minute-seconds to the desired values

Users are allowed 3 deferrals. A deadline date is enforced.
Dialog will switch to aggressive mode after 3 deferrals or the deadline date has passed.

Created: 1/7/2025 | Howie Canterbury
Updated: 6/2/2025
---------------------------
ABOUT_THIS_SCRIPT

# Variables
org="yourOrg" # Replace with your organization name
dialogBinary="/usr/local/bin/dialog"
reqVersion="$4" # Parameter 4
currentVersion=$(/usr/bin/sw_vers | grep "ProductVersion" | /usr/bin/awk '{ print $2 }')
releaseNotes="$5" # Parameter 5
epochTime=$(/bin/date +%s)
deadlineDateSec="$7" # Parameter 7
deadlineDate=$(/bin/date -r "$deadlineDateSec" "+%m/%d/%Y")
jamfBinary="/usr/local/jamf/bin/jamf"
managementFolder="/usr/local/Management"
deferDateTime=$(/bin/date -r "$epochTime" "+%m/%d/%Y %X")
deferPLIST="/usr/local/Management/com.${org}.macOSUpdateDeferral.plist"
deferCount=$(/usr/bin/defaults read "$deferPLIST" Defer)
deferralsRemaining=$(/usr/bin/defaults read "$deferPLIST" DeferralsRemaining)
timerSec="$6" # Parameter 6
reqosMajor="$8" # Parameter 8
reqosMinor="$9" # Parameter 9
icon="$10" # Parameter 10
launchDaemon="/Library/LaunchDaemons/com.${org}.macOSUpdate.plist"
ldaemonRunning=$(/bin/launchctl list | grep "com.${org}.macOSUpdate" | /usr/bin/awk '{print $3}')

# Log
logFile="/private/var/log/macOS-Software-Update.log"

############################################################################
# Data to be displayed in Swift Dialog in table form
############################################################################

# Display current and required macOS versions
macOSVersion="|  |  |
| -------- | ------- |
| Current macOS | "${currentVersion}" |
| Required update | "${reqVersion}" |"

# Display available deferrals, deferrals remaining, and the update deadline
enforceUpdate="|  |  |
| -------- | ------- |
| Deferrals used | "${deferCount}" |
| Deferrals available | "${deferralsRemaining}" |
| Update deadline | $deadlineDate"

# Initial data to be displayed in the Dialog window
enforceInitial="|  |  |
| -------- | ------- |
| Deferrals used | "0" |
| Deferrals available | "3" |
| Update deadline | $deadlineDate"

############################################################################
# Functions
############################################################################

# Log function
updateLog() {
	if [ ! -f "$logFile" ]; then
		touch "$logFile"
	fi
	echo -e "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$logFile"
	echo "$1" # To Jamf policy log
}

# Swift Dialog check
swiftDialogCheck() {
	if [ ! -f "$dialogBinary" ]; then
		updateLog "Swift Dialog is not installed. Installing..."
		"$jamfBinary" policy -event install-swiftdialog --forceNoRecon
	elif [ -f "$dialogBinary" ]; then
		updateLog "Swift Dialog is installed. Continuing..."
	fi
	# Create Management folder
	if [ ! -d "$managementFolder" ]; then
		mkdir "$managementFolder"
	fi
}

# Launch Safari and load release notes
macOSinfo() {
	updateLog "User requested to read release notes. Opening macOS release notes"
	open -a "Safari.app" "$releaseNotes"
}

# Deploy script that will check if deferral has elapsed and trigger the policy to run again if needed
deferralCheckScript() {
	if [ ! -f "/usr/local/Management/macOSUpdateTrigger.sh" ]; then
		# Deploy deferral check script
		tee "/usr/local/Management/macOSUpdateTrigger.sh" << "EOF"
	#!/bin/zsh
	
	# What is the current epoch time?
	epochTime=$(/bin/date +%s)
	
	# Script variables
	jamfBinary="/usr/local/jamf/bin/jamf"
	deferPLIST="/usr/local/Management/com.${org}.macOSUpdateDeferral.plist"
	startTime=$(/usr/bin/defaults read $deferPLIST StartTime "$epochTime")
	deferToTime=$(/usr/bin/defaults read $deferPLIST DeferToTime)
	deferDateTime=$(/bin/date -r "$epochTime" "+%m/%d/%Y %X")
	deferInterval=$(/usr/bin/defaults read "$deferPLIST" DeferInterval)
	updateCanceled="/usr/local/Management/UserCanceledmacOSUpdate"
	deadlineDateSec=$(/usr/bin/defaults read "$deferPLIST" DeadlineDate)
	deadlineDate=$(/bin/date -r "$deadlineDateSec" "+%m/%d/%Y")
	
	# Log
	logFile="/private/var/log/macOS-Software-Update.log"
	
	# Log function
	updateLog() {
		if [ ! -f "$logFile" ]; then
			touch "$logFile"
		fi
		echo -e "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$logFile"
		echo "$1"
	}
	
	checkTime() {
		deferEnds=$(/bin/date -r "$deferToTime" "+%m/%d/%Y %X")
		updateLog "Checking if deferral time has elapsed. Will run macOS update policy if it has."
		currentTime=$(/bin/date +%s)
		checkDefer=$(($currentTime - $startTime))
		if [ "$checkDefer" -ge "$deferInterval" ]; then
			# Run policy
			updateLog "Deferral time has elapsed. Running macOS update policy"
			$jamfBinary policy -event update-macos
		else
			updateLog "Deferral interval has not yet elapsed. Deferral end time is $deferEnds. The deadline date is $deadlineDate."
		fi
	}
	
	jss_Check() {
		jssCheck=$("$jamfBinary" checkJSSConnection | awk 'NR==2' | sed 's/\.//g')
		if [ "$jssCheck" = "The JSS is available" ]; then
			echo "The JSS is available. Deferral check can proceed"
		else
			echo "The JSS is NOT available. Exiting..."
			exit 0
		fi
	}
	
	# Check if the JSS is available. Run the deferral time check and check if user canceled the update
	jss_Check
	if [ -f "$deferPLIST" ]; then
		checkTime
	elif [ ! -f "$deferPLIST" ] && [ -f "$updateCanceled" ]; then
		updateLog "User canceled the update"
		$jamfBinary policy -event update-macos
	elif [ ! -f "$deferPLIST" ]; then
		$jamfBinary policy -event update-macos	
	fi
	
	exit 0
EOF
		# Set ownership and permissions
		/usr/sbin/chown root:wheel "/usr/local/Management/macOSUpdateTrigger.sh"
		/bin/chmod +x "/usr/local/Management/macOSUpdateTrigger.sh"
	elif [ -f "/usr/local/Management/macOSUpdateTrigger.sh" ]; then
		echo "Deferral check script already deployed"
	fi
}

# Create launch daemon to run script to check update deferral
createLaunchDaemon() {
	if [ ! -f "$launchDaemon" ]; then
	# Create the launch daemon
	updateLog "Creating LaunchDaemon..."
	cat << EOF > "$launchDaemon"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.${org}.macOSUpdate</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>-c</string>
		<string>/usr/local/Management/macOSUpdateTrigger.sh</string>
	</array>
	<key>StandardOutPath</key>
	<string>/var/log/MULaunchD.log</string>
	<key>StandardErrorPath</key>
	<string>/var/log/MULaunchDError.log</string>
	<key>RunAtLoad</key>
	<false/>
	<key>StartInterval</key>
	<integer>600</integer>
	<key>UserName</key>
	<string>root</string>
</dict>
</plist>
EOF

		# Set the correct permissions
		updateLog "Setting permissions for launch daemon plist..."
		chmod 644 "$launchDaemon" || { updateLog "Failed to set permissions on $launchDaemon"; exit 1; }
		chown root:wheel "$launchDaemon" || { updateLog "Failed to change owner of $launchDaemon"; exit 1; }
		
		# Load the LaunchDaemon
		updateLog "Loading the launch daemon"
		/bin/launchctl bootstrap system "$launchDaemon" || { updateLog "Failed to bootstrap $launchDaemon"; exit 1; }
		
		updateLog "LaunchDaemon setup completed successfully."
		
		# Install deferral check script
		deferralCheckScript
	fi
	
}

# Launch Software Update; write notification if user does not run the update
softwareUpdate() {
	updateLog "Opening Software Update... Scanning for updates"
	open -a "Software Update"
	softwareupdate -l
	# Create user canceled file to catch users who canceled the update
	touch ${managementFolder}/UserCanceledmacOSUpdate
	# Deploy launch daemon to prompt the user again if they do not update
	createLaunchDaemon
	# Update inventory
	echo "Updating inventory"
	"$jamfBinary" recon
}

# Check current installed macOS version
macOSVersionCheck() {
	# Define variables
	local macOSVersion=$(/usr/bin/sw_vers | grep "ProductVersion" | /usr/bin/awk '{ print $2 }')
	local osMajor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
	local osMinor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')
	local reqOS="${reqosMajor}.${reqosMinor}"
	local policyFiles=(
		"/usr/local/Management/com.${org}.macOSUpdateDeferral.plist"
		"/usr/local/Management/UserCanceledmacOSUpdate"
		"/usr/local/Management/macOSUpdateTrigger.sh"
		"/Library/LaunchDaemons/com.${org}.macOSUpdate.plist"
	)
	
	echo "Required macOS version is ${reqOS}"
	echo "Current installed macOS version is $macOSVersion"
	
	if [ "$osMajor" -ge "$reqosMajor" ] && [ "$osMinor" -ge "$reqosMinor" ]; then
		updateLog "The current installed macOS version is greater than or equal to the required version. No update needed. Exiting..."
		# Look for deferral PLIST or user canceled macOS update file and delete
		for file in "${policyFiles[@]}"; do
			echo "Found $file. Deleting..."
			rm -f "$file"
		done
		# Run inventory
		"$jamfBinary" recon
		# Stop here. No update is needed.
		exit 0
	else
		updateLog "The current installed macOS version is less than the required version. Update is needed."
	fi
}

# Check for and remove macOS installer app(s)
checkformacOSInstaller() {
	local appDirectory="/Applications"
	local macOSInstaller=$(find "$appDirectory" -maxdepth 1 -type d -name "Install macOS *.app")
	
	if [ ${#macOSInstaller[@]} -gt "0" ]; then
		echo "macOS installers found in $appDirectory"
		for installer in "${macOSInstaller[@]}"; do
			echo "Deleting $installer"
			rm -rf "$installer"
		done
	fi
}

################## Meeting Check ##################

checkZoomMeeting(){
	# Zoom processes
	zoomMeeting=$(lsof -i 4UDP | grep zoom | awk 'END{print NR}')
	if [ "$zoomMeeting" -gt 1 ]; then
		ZoominMeeting=yes
	elif [ "$zoomMeeting" -le 1 ]; then
		ZoominMeeting=no
	else
		ZoominMeeting=no
	fi
}

checkTeamsMeeting(){
	# Teams processes
	teamsMeeting=$(lsof -i 4UDP | grep "Teams" | awk 'END{print NR}')
	if [ "$teamsMeeting" -gt 3 ]; then
		TeamsinMeeting=yes
	elif [ "$teamsMeeting" -le 3 ]; then
		TeamsinMeeting=no
	else
		TeamsinMeeting=no
	fi
}

checkforMeetings() {
	checkZoomMeeting 
	checkTeamsMeeting 
}

################## User Deferral ##################
one_Hour() {
	local interval="3600"
	# Enter the defer time interval
	/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
	# Enter the current time
	/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
	# Enter deferral to time
	local defer=$(($epochTime + $interval))
	# What time is the deferral over?
	/usr/bin/defaults write "$deferPLIST" DeferToTime "$defer"
	
	# Set permission for management folder and deferral PLIST
	chmod -R 755 "$managementFolder"
	chmod 644 "$deferPLIST"
	
	# Deploy the launch daemon to trigger the policy after deferral
	createLaunchDaemon
	
	# Update inventory
	echo "Updating inventory"
	"$jamfBinary" recon
}

one_Hour_Auto() {
	# This is ran only if a meeting is in progress when the policy runs.
	updateLog "A meeting is in progress. Automatically deferring for one hour."
	if [ -f "$deferPLIST" ]; then
		local interval="3600"
		# Enter the defer time interval
		/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
		# Enter the current time
		/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
		# Enter deferral to time
		local defer=$(($epochTime + $interval))
		# What time is the deferral over?
		/usr/bin/defaults write "$deferPLIST" DeferToTime "$defer"
	elif ! [ -f "$deferPLIST" ]; then
		local interval="3600"
		# Write blank values for DateTime, Defer, and DeferralsRemaining
		/usr/bin/defaults write "$deferPLIST" DateTime ""
		/usr/bin/defaults write "$deferPLIST" Defer ""
		/usr/bin/defaults write "$deferPLIST" DeferralsRemaining ""
		# Enter the defer time interval
		/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
		# Enter the current time
		/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
		# Calculate deferral end time
		local defer=$(($epochTime + $interval))
		# What time is the deferral over?
		/usr/bin/defaults write "$deferPLIST" DeferToTime "$defer"
		# Write the deadline date into the PLIST
		/usr/bin/defaults write "$deferPLIST" DeadlineDate "$deadlineDateSec"
	fi
	
	# Set permission for management folder and deferral PLIST
	chmod -R 755 "$managementFolder"
	chmod 644 "$deferPLIST"
	
	# Deploy the launch daemon to trigger the policy after deferral
	createLaunchDaemon
	
	# Update inventory
	echo "Updating inventory"
	"$jamfBinary" recon
}

four_Hours() {
	local interval="14400"
	# Enter the defer time interval
	/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
	# Enter the current time
	/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
	# Enter deferral to time
	local defer=$(($epochTime + $interval))
	# What time is the deferral over?
	defaults write "$deferPLIST" DeferToTime "$defer"
	
	# Set permission for management folder and deferral PLIST
	chmod -R 755 "$managementFolder"
	chmod 644 "$deferPLIST"
	
	# Deploy the launch daemon to trigger the policy after deferral
	createLaunchDaemon
	
	# Update inventory
	echo "Updating inventory"
	"$jamfBinary" recon
}

four_Hour_Auto() {
	# This is ran only if the timer runs out. 
	if [ -f "$deferPLIST" ]; then
		updateLog "Timer ran out. Automatically setting deferral for 4 hours"
		local interval="14400"
		# Enter the defer time interval
		/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
		# Enter the current time
		/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
		# Enter deferral to time
		local defer=$(($epochTime + $interval))
		# What time is the deferral over?
		/usr/bin/defaults write "$deferPLIST" DeferToTime "$defer"
	elif [ ! -f "$deferPLIST" ]; then
		updateLog "Timer ran out. Automatically setting deferral for 4 hours"
		local interval="14400"
		# Write blank values for DateTime, Defer, and DeferralsRemaining
		/usr/bin/defaults write "$deferPLIST" DateTime ""
		/usr/bin/defaults write "$deferPLIST" Defer ""
		/usr/bin/defaults write "$deferPLIST" DeferralsRemaining ""
		# Enter the defer time interval
		/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
		# Enter the current time
		/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
		# Calculate deferral end time
		local defer=$(($epochTime + $interval))
		# What time is the deferral over? 
		/usr/bin/defaults write "$deferPLIST" DeferToTime "$defer"
		# Write the deadline date into the PLIST
		/usr/bin/defaults write "$deferPLIST" DeadlineDate "$deadlineDateSec"
	fi
	
	# Set permission for management folder and deferral PLIST
	chmod -R 755 "$managementFolder"
	chmod 644 "$deferPLIST"
	
	# Deploy the launch daemon to trigger the policy after deferral
	createLaunchDaemon
	
	# Update inventory
	echo "Updating inventory"
	"$jamfBinary" recon
}


one_Day() {
	local interval="86400"
	# Enter the defer time interval
	/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
	# Enter the current time
	/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
	# Enter deferral to time
	local defer=$(($epochTime + $interval))
	# What time is the deferral over?
	/usr/bin/defaults write "$deferPLIST" DeferToTime "$defer"
	
	# Set permission for management folder and deferral PLIST
	chmod -R 755 "$managementFolder"
	chmod 644 "$deferPLIST"
	
	# Deploy the launch daemon to trigger the policy after deferral
	createLaunchDaemon
	
	# Update inventory
	echo "Updating inventory"
	"$jamfBinary" recon
}

five_Min() {
	# This is only used for testing
	local interval="300"
	# Enter the defer time interval
	/usr/bin/defaults write "$deferPLIST" DeferInterval "$interval"
	# Enter the current time
	/usr/bin/defaults write "$deferPLIST" StartTime "$epochTime"
	# Enter deferral to time
	defer=$(($epochTime + $interval))
	# What time is the deferral over?
	/usr/bin/defaults write "$deferPLIST" DeferToTime "$defer"
	
	# Set permission for management folder and deferral PLIST
	chmod -R 755 "$managementFolder"
	chmod 644 "$deferPLIST"
	
	# Deploy the launch daemon to trigger the policy after deferral
	createLaunchDaemon
	
	# Update inventory
	echo "Updating inventory"
	"$jamfBinary" recon
}

setDeferral() {
	# Set deferral start time, interval, end time
	if [ "$outPut" = "1" ]; then
		# Update deferral PLIST for 1 hour
		updateLog "Setting deferral for 1 hour"	
		one_Hour 
	elif [ "$outPut" = "2" ]; then
		# Udate deferral PLIST for 4 hours
		updateLog "Setting deferral for 4 hours"
		four_Hours
	elif [ "$outPut" = "3" ]; then
		# Udate deferral PLIST for 1 day
		updateLog "Setting deferral for 1 day"
		one_Day 
	elif [ "$outPut" = "4" ]; then
		# Udate deferral PLIST for 5 minutes
		updateLog "Setting deferral for 5 minutes"
		five_Min
	fi
}

userDefer() {
	dateTime=$(/usr/bin/defaults read "$deferPLIST" DateTime)
	# Check if PLIST exists or if DateTime has no value. An auto defer would not write a value to DateTime.
	if [ ! -f "$deferPLIST" ] || [ "$dateTime" = "" ]; then
		updateLog "User opted to defer. Deferrals remaining: 2"
		/usr/bin/defaults write "$deferPLIST" DateTime "$deferDateTime"
		/usr/bin/defaults write "$deferPLIST" Defer 1
		/usr/bin/defaults write "$deferPLIST" DeferralsRemaining 2
		/usr/bin/defaults write "$deferPLIST" DeferInterval ""
		/usr/bin/defaults write "$deferPLIST" DeferToTime ""
		/usr/bin/defaults write "$deferPLIST" StartTime ""
		# Write the deadline date into the PLIST
		/usr/bin/defaults write "$deferPLIST" DeadlineDate "$deadlineDateSec"
	fi
	if [ "$deferCount" = "1" ]; then
		updateLog "User opted to defer. Deferrals remaining: 1"
		/usr/bin/defaults write "$deferPLIST" DateTime "$deferDateTime"
		/usr/bin/defaults write "$deferPLIST" Defer 2
		/usr/bin/defaults write "$deferPLIST" DeferralsRemaining 1
	fi
	if [ "$deferCount" = "2" ]; then
		updateLog "User opted to defer. Deferrals remaining: 0"
		/usr/bin/defaults write "$deferPLIST" DateTime "$deferDateTime"
		/usr/bin/defaults write "$deferPLIST" Defer 3
		/usr/bin/defaults write "$deferPLIST" DeferralsRemaining 0
	fi
	
	# Change permission on PLIST to allow reading from Finder.
	chmod -R 755 "$managementFolder"
	chmod 644 "$deferPLIST"
	
	# Set deferral time based on user selection from Swift Dialog
	setDeferral 
}

################## Check if deadline date has passed ##################
deadlineCheck() {
	if [ "$epochTime" -ge "$deadlineDateSec" ]; then
		echo "Deadline has arrived"
	else
		echo "Deadline has not arrived"
	fi
}

################## Dialog settings ##################
# -o option allows the Dialog window to be moveable.  
# -p option places the Dialog window on top. Users can move the Dialog window but it will always be on top. --blurscreen option blurs everything behind the Dialog window.
# The deadline date is checked before the Dialog window is shown. Users may have available deferrals but if the deadline has passed, Dialog will go into aggressive mode.
displayDialog() {
		if [ "$deferralsRemaining" = "2" ] && [ "$epochTime" -lt "$deadlineDateSec" ]; then
			"$dialogBinary" \
			-o \
			-p \
			--title "A macOS Update is required" \
			--titlefont "size=24,weight=bold" \
			--message "Please update to macOS "$reqVersion". macOS updates must be performed regularly to receive bug fixes and security updates. Select **Update Now** to install this update. A restart will be required. You can defer the update up to 3 times before the update deadline date. \n${macOSVersion} \n\n\n${enforceUpdate} \n\n If timer runs out an automatic 4-hour deferral will be set." \
			--icon "$icon" \
			--appearance light \
			--iconsize "150" \
			--button1text "Run" \
			--selecttitle "Deferral Options" \
			--selectvalues "Update Now, 1 Hour, 4 Hours, 1 Day" \
			--selectdefault "Update Now" \
			--infobuttontext "About macOS $reqVersion" \
			--infobuttonaction "$releaseNotes" \
			--height "600" \
			--width "900" \
			--timer $timerSec
			
		elif [ "$deferralsRemaining" = "1" ] && [ "$epochTime" -lt "$deadlineDateSec" ]; then
			"$dialogBinary" \
			-o \
			-p \
			--quitkey 0 \
			--title "A macOS Update is required" \
			--titlefont "size=24,weight=bold" \
			--message "Please update to macOS "$reqVersion". macOS updates must be performed regularly to receive bug fixes and security updates. Select **Update Now** to install this update. A restart will be required. You can defer the update up to 3 times before the update deadline date. \n${macOSVersion} \n\n\n${enforceUpdate} \n\n If timer runs out an automatic 4-hour deferral will be set." \
			--icon "$icon" \
			--appearance light \
			--iconsize "150" \
			--button1text "Run" \
			--selecttitle "Deferral Options" \
			--selectvalues "Update Now, 1 Hour, 4 Hours, 1 Day" \
			--selectdefault "Update Now" \
			--infobuttontext "About macOS $reqVersion" \
			--infobuttonaction "$releaseNotes" \
			--height "600" \
			--width "900" \
			--timer $timerSec
			
		elif [ "$deferralsRemaining" = "0" ] || [ "$epochTime" -ge "$deadlineDateSec" ]; then
			# AGGRESSIVE MODE - Unmovable Dialog window, blurred full screen
			"$dialogBinary" \
			-p \
			--quitkey 0 \
			--blurscreen \
			--title "A macOS Update is required" \
			--titlefont "size=24,weight=bold" \
			--message "Please update to macOS "$reqVersion". Select **Update Now** to install this update. A restart will be required. \n${macOSVersion} \n\n\n${enforceUpdate} \n\n **There are no deferrals left**." \
			--icon "$icon" \
			--appearance light \
			--iconsize "150" \
			--button1text "Run" \
			--selectvalues "Update Now" \
			--selectdefault "Update Now" \
			--height "600" \
			--width "900"
		
		else
		
		# First time Dialog is launched
		"$dialogBinary" \
		-o \
		-p \
		--title "A macOS Update is required" \
		--titlefont "size=24,weight=bold" \
		--message "Please update to macOS "$reqVersion". macOS updates must be performed regularly to receive bug fixes and security updates. Select **Update Now** to install this update. A restart will be required. You can defer the update up to 3 times before the update deadline date. \n${macOSVersion} \n\n\n${enforceInitial} \n\n If timer runs out an automatic 4-hour deferral will be set." \
		--icon "$icon" \
		--appearance light \
		--iconsize "150" \
		--button1text "Run" \
		--selecttitle "Deferral Options" \
		--selectvalues "Update Now, 1 Hour, 4 Hours, 1 Day" \
		--selectdefault "Update Now" \
		--infobuttontext "About macOS $reqVersion" \
		--infobuttonaction "$releaseNotes" \
		--height "600" \
		--width "900" \
		--timer $timerSec
	fi
	dialogResults=$?
}

# Expired deadline - NOT CURRENTLY IN USE
expiredDeadline() {
	"$dialogBinary" \
	-p \
	--quitkey 0 \
	--blurscreen \
	--title "A macOS Update is required" \
	--titlefont "size=24,weight=bold" \
	--message "Please update to macOS "$reqVersion". Select **Update Now** to install this update. A restart will be required. \n${macOSVersion} \n\n\n${enforceUpdate} \n\n **The update deadline has passed**." \
	--icon "$icon" \
	--appearance light \
	--iconsize "150" \
	--button1text "Run" \
	--selecttitle "Deferral Options" \
	--selectvalues "Update Now" \
	--selectdefault "Update Now" \
	--height "600" \
	--width "900"
	
	dialogResults=$?
}

############################################################################
# Run the engine
#
# Display Dialog prompting user to run macOS update 
############################################################################

# Before doing anything, check if the current installed macOS version is greater than or equal to the required version.
updateLog "Checking if a macOS update is needed."
macOSVersionCheck

# If an update is required...
updateLog "Starting macOS update prompt. Running checks..."

# Delete macOS installer if present. This is done to ensure that major upgrades will run through Software Update.
# Users who are not admin will not be able to use the macOS install app to perform a major upgrade.
echo "Checking for macOS install apps..."
checkformacOSInstaller

# Check if Swift Dialog is installed. Create Management folder if it doesn't exist.
echo "Checking if Swift Dialog is installed..."
swiftDialogCheck

# Check if a meeting is in progress
updateLog "Checking if a meeting is in progress."
checkforMeetings

# Display Dialog window prompting the user to update
# Decide if Dialog will be launched after meeting check
# Comment out these steps if you are testing this while stuck in a meeting
if [ "$ZoominMeeting" = yes ] || [ "$TeamsinMeeting" = yes ]; then
	# Auto-defer for 1 hour
	one_Hour_Auto
	# Exit to stop script run. Otherwise it will count as a null output code which will trigger a 4-hour auto-deferral
	exit 0
elif [ "$ZoominMeeting" = no ] && [ "$TeamsinMeeting" = no ]; then
	updateLog "No meeting in progress. Displaying Dialog to update macOS"
	# Display Dialog window notifying the user that a reboot is needed
	outPut=$(displayDialog | grep "SelectedIndex" | awk -F ": " '{print $NF}')
	if [ "$outPut" = "" ]; then
		echo "No user input"
	else
		updateLog "Dialog returned code $outPut"
	fi
fi

# Test command to run while stuck in a meeting! Dialog won't display if a meeting is in progress. Comment out when this script is in production.
	#outPut=$(displayDialog | grep "SelectedIndex" | awk -F ": " '{print $NF}')

# Echo results for testing. Comment out when this script is in production.
	#echo "Output is $outPut"
	#echo "Dialog result is $dialogResults"

# Process user input from Dialog
case $outPut in
	0)
		updateLog "User opted to update now"
		# Launch Software Update and scan for available updates
		softwareUpdate
	;;
	1 | 2 | 3 | 4)
		# Run User Defer function
		userDefer 
	;;
	"")
		four_Hour_Auto
	;;
esac