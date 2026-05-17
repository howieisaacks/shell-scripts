#!/bin/zsh --no-rcs

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

:<<INFO
----------------------------------------
TITLE: Post ZTP
VERSION: 6.0
PURPOSE: Checks for apps that should have installed during ZTP. Installs any that are missing. Installs remaining apps and configurations.

Results from the app installs and outdated macOS enrollment checks are recorded to PLISTs.
This script was intended to be used with a ZTP success/fail workflow. A PLIST is created at the end of the ZTP process that records the success or fail
of app installs. This script will check that PLIST to look for any apps that failed, and if they were installed successfully by this script, the PLIST is updated
to show that the apps were installed.

Edit the app_array variables in check_ztp_apps, check_post_ztp_apps, and check_remediated_apps with your own apps, app file paths, and Jamf Pro policy custom triggers.

4/15/2026 | Howie Canterbury
----------------------------------------
INFO

# SCRIPT GLOBAL VARIABLES
# -----------------------------------
script_version="6.0"
script_name="${0:t:r}"
currentUser=$(/usr/bin/stat -f "%Su" /dev/console)
flag="/Users/$currentUser/.Post_ZTP_Ran"

# LOG FUNCTION
# -----------------------------------
logFile="/private/var/log/Post-ZTP.log"
updateLog() {
	local message="$1"
	local timestamp
	timestamp=$(/bin/date "+%Y-%m-%d %H:%M:%S")

	echo "${timestamp} | ${message}" | /usr/bin/tee -a "$logFile"
}

# JAMF PRO FUNCTIONS
# -----------------------------------

# Jamf agent
jamfAgent="/usr/local/jamf/bin/jamf"

# Jamf policy function
jamfPolicy() {
	# To use run the function name followed by the policy custom trigger
	local policy="$1"
	"$jamfAgent" policy -event "$policy" --forceNoRecon > /dev/null 2>&1
}

# Stop Jamf launch daemon
stop_Jamf_launchdaemon() {
	# Jamf Pro launch daemon
	local jamflaunchDaemon="/Library/LaunchDaemons/com.jamfsoftware.task.1.plist"
	# Stop the Jamf launch daemon to prevent other policies from running
	if [[ $(/bin/launchctl list | grep com.jamfsoftware.task.E) ]]; then
		updateLog "Stopping Jamf launch daemon"
		/bin/launchctl bootout system "${jamflaunchDaemon}"
	fi
}

# Start Jamf launch daemon
start_Jamf_launchdaemon() {
	# Jamf Pro launch daemon
	local jamflaunchDaemon="/Library/LaunchDaemons/com.jamfsoftware.task.1.plist"
	# Start the Jamf launch daemon
	if ! [[ $(/bin/launchctl list | grep com.jamfsoftware.task.E) ]]; then
		updateLog "Starting Jamf launch daemon"
		/bin/launchctl bootstrap system "${jamflaunchDaemon}"
	fi
}

# Check if Jamf launch daemon is running - NOT IN CURRENT USE
check_jamf_launchdaemon() {
	updateLog "Checking Jamf launch daemon status..."
	if [[ $(/bin/launchctl list | grep com.jamfsoftware.task.E) ]]; then
		updateLog "Jamf Pro launch daemon found to be running. Stopping..."
		stop_Jamf_launchdaemon
	fi
}

# Check computer name; rename to serial if needed
check_computer_name() {
	updateLog "Checking if computer name was set correctly..."
	local serial=$(ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F\" '/IOPlatformSerialNumber/{print $4}')
	local computer_name=$(hostname)
	updateLog "Current computer name is ${computer_name}"
	if [[ "$computer_name" = "$serial" ]]; then
		updateLog "Computer name setting successful"
	else
		updateLog "Computer name failed to set during ZTP. Setting to "${serial}""
		"$jamfAgent" setComputerName -name "${serial}"
	fi
}

# CHECK ZTP APP INSTALLS; INSTALL REMAINING APPS; CHECK FOR REMEDIATED FAILED INSTALLS
# -----------------------------------

# ZTP PLIST
ztp_check_plist="/usr/local/Management/com.eleven9.ztp.plist"
failed_installs=$(xmllint --xpath '//key[.="FailedInstalls"]/following-sibling::array[1]/string' "$ztp_check_plist" 2>/dev/null | \
	sed -n 's:.*<string>\(.*\)</string>.*:\1:p')

# Write updates to the PLIST
update_plist() {
	# Command to set a key and value to PLIST
	/usr/libexec/PlistBuddy -c "Set :${1} ${2}" "$ztp_check_plist"
}

# ZTP apps
check_ztp_apps() {
	# To add new apps use format: "App Name","App Path","Jamf Pro custom trigger"
	local app_array=(
		# App name - App path - Install policy custom trigger
		"Google Chrome","/Applications/Google Chrome.app","install-chrome"
		"Microsoft Edge","/Applications/Microsoft Edge.app","install-edge"
		"Microsoft Excel","/Applications/Microsoft Excel.app","install-excel"
		"OneDrive","/Applications/OneDrive.app","install-onedrive"
		"Microsoft OneNote","/Applications/Microsoft OneNote.app","install-onenote"
		"Microsoft Outlook","/Applications/Microsoft Outlook.app","install-outlook"
		"Microsoft PowerPoint","/Applications/Microsoft PowerPoint.app","install-powerpoint"
		"Microsoft Teams","/Applications/Microsoft Teams.app","install-teams"
		"Microsoft Word","/Applications/Microsoft Word.app","install-word"
		"Zoom","/Applications/zoom.us.app","install-zoom"
		"ForeScout Secure Connector","/Applications/ForeScout SecureConnector.app","install-forescout"
		"Global Protect","/Applications/GlobalProtect.app","install-globalprotect"
		"CrowdStrike","/Applications/Falcon.app","install-crowdstrike"
		"Tanium","/Library/Tanium/TaniumClient/TaniumClient","install-tanium"
	)
	
	# Count of ZTP apps
	local ztp_apps=$(echo ${#app_array[@]})
	echo "Expect ${ztp_apps} apps"
	
	# Run checks; report status; install if needed
	updateLog "Checking if all ZTP apps installed. Apps that failed to install during ZTP will be installed."
	for app in "${app_array[@]}"; do
		local app_name=$(echo "$app" | cut -d ',' -f1)
		local app_path=$(echo "$app" | cut -d ',' -f2)
		local install_policy=$(echo "$app" | cut -d ',' -f3)
		if [[ -d "$app_path" ]] || [[ -f "$app_path" ]]; then
			updateLog "${app_name} - Installed"
		elif  [[ ! -d "$app_path" ]] || [[ ! -f "$app_path" ]]; then
			updateLog "${app_name} - not installed. Running policy: ${install_policy}"
			jamfPolicy $install_policy
		fi
	done
}

# Post ZTP apps, angents, and fonts
check_post_ztp_apps() {
	# To add new apps use format: "App Name","App Path","Jamf Pro custom trigger"
	local app_array=(
		# App name - App path - Install policy custom trigger
		"Barlow Font","/Library/Fonts/BarlowCondensed-Medium.ttf","install-barlow"
		"Calibre Font","/Library/Fonts/Calibre-Regular.otf","install-calibre"
		"Financier Font","/Library/Fonts/FinancierDisplay-Regular.otf","install-financier"
		"Noto Sans Font","/Library/Fonts/NotoSansCJKjp-Regular.otf","install-notosans"
		"Noto Serif Font","/Library/Fonts/NotoSerifCJKjp-Regular.otf","install-notoserif"
		"Space Mono Font","/Library/Fonts/SpaceMono-Regular.ttf","install-spacemono"
		"Tenable","/Library/NessusAgent/run/sbin/nessus-agent-module","install-tenable"
		"Proofpoint DLP","/Library/PEA/agent/ITProtector.app","install-ppdlp"
		"Company Portal","/Applications/Company Portal.app","install-companyportal"
		"Inventory every 4 hours","/Library/Scripts/Send_Inventory.sh","install-inventoryevery4"
	)
	
	local post_ztp_apps=$(echo ${#app_array[@]})
	echo "Expect ${post_ztp_apps} post ZTP apps"
	
	# Run checks; report status; install if needed
	updateLog "Installing remaining company apps and configurations if not already installed."
	for app in "${app_array[@]}"; do
		local app_name=$(echo "$app" | cut -d ',' -f1)
		local app_path=$(echo "$app" | cut -d ',' -f2)
		local install_policy=$(echo "$app" | cut -d ',' -f3)
		#updateLog "Checking ${app_name}"
		if [[ -d "$app_path" ]] || [[ -f "$app_path" ]]; then
			updateLog "${app_name} - installed"
		elif  [[ ! -d "$app_path" ]] || [[ ! -f "$app_path" ]]; then
			updateLog "${app_name} - not installed. Running policy: $install_policy"
			jamfPolicy $install_policy
		fi
	done
}

# Check if failed app installs have been remediated
check_remediated_apps() {
	if [[ -f "$failed_installs" ]]; then
	local app_array=(
		"Google Chrome","/Applications/Google Chrome.app"
		"Microsoft Edge","/Applications/Microsoft Edge.app"
		"Microsoft Excel","/Applications/Microsoft Excel.app"
		"OneDrive","/Applications/OneDrive.app"
		"Microsoft OneNote","/Applications/Microsoft OneNote.app"
		"Microsoft Outlook","/Applications/Microsoft Outlook.app"
		"Microsoft PowerPoint","/Applications/Microsoft PowerPoint.app"
		"Microsoft Teams","/Applications/Microsoft Teams.app"
		"Microsoft Word","/Applications/Microsoft Word.app"
		"Zoom","/Applications/zoom.us.app"
		"ForeScout Secure Connector","/Applications/ForeScout SecureConnector.app"
		"Global Protect","/Applications/GlobalProtect.app"
		"CrowdStrike","/Applications/Falcon.app"
		"Tanium","/Library/Tanium/TaniumClient/TaniumClient"
	)
	
	# Count of ZTP apps
	local ztp_apps=$(echo "${#app_array[@]}")
	
	updateLog "Checking that all app install failures have been remediated."
	for app in "${app_array[@]}"; do
		local app_name=$(echo "$app" | cut -d ',' -f1)
		local app_path=$(echo "$app" | cut -d ',' -f2)
		updateLog "Checking ${app_name}"
		if [[ -d "$app_path" ]] || [[ -f "$app_path" ]]; then
			((new_installed_count++))
		elif  [[ ! -d "$app_path" ]] || [[ ! -f "$app_path" ]]; then
			((not_remed_installed_count++))
		fi
	done
	
	# Breakdown of results
	success_ratio="${ztp_apps}.${ztp_apps}"
	new_installed_ratio="${new_installed_count}.${ztp_apps}"
	
	success_var1=$(echo "$success_ratio" | /usr/bin/awk -F. '{print $1}')
	success_var2=$(echo "$success_ratio" | /usr/bin/awk -F. '{print $2}')
	
	new_installed_var1=$(echo "$new_installed_ratio" | /usr/bin/awk -F. '{print $1}')
	new_installed_var2=$(echo "$new_installed_ratio" | /usr/bin/awk -F. '{print $2}')
	
	# Report results
	if [[ "$new_installed_var1" = "$success_var1" ]] && [[ "$new_installed_var2" = "$success_var2" ]]; then
		updateLog "All failed installs have been remediated!"
		remediated="Yes"
		# Write remediated status to the PLIST
		update_plist Remediated "${remediated}"
		# Update PLIST permissions
		chmod 644 $ztp_check_plist
	else
		updateLog "Failed installs have not been remediated."
		remediated="No"
		# Write remediated status to the PLIST
		update_plist Remediated "${remediated}"
		# Update PLIST permissions
		chmod 644 $ztp_check_plist
	fi
	else
		return 0
	fi
}

# CHECK FOR AND DELETE PSSO AND ONEDRIVE SETUP PROMPT FILES
# -----------------------------------
delete_psso_onedrive_setup() {
	prompt_files=(
		"/Library/LaunchDaemons/com.eleven9.psso-onedrive.plist"
		"/private/var/log/PSSO-OneDrive-LaunchD.log"
		"/private/var/log/PSSO-OneDrive-Error.log"
	)
	
	setup_done="/Users/$currentUser/.PSSO_OneDrive_Done"
	
	if [[ -f "$setup_done" ]]; then
	updateLog "Checking for PSSO and OneDrive setup prompt files"
	
		# Check if launch daemon is running
		if [[ $(/bin/launchctl list | grep com.eleven9.psso-onedrive) ]]; then
			updateLog "PSSO and OneDrive setup launch daemon found. Unloading."
			/bin/launchctl bootout system /Library/LaunchDaemons/com.eleven9.psso-onedrive.plist
		fi
		
		found_file="0"
		
		for file in "${prompt_files[@]}"; do
			if [[ -f "$file" ]]; then
				updateLog "Found file at ${file}. Deleting..."
				rm -f "$file"
				found_file="1"
			fi
		done
		
		if [[ "$found_file" == "0" ]]; then
			updateLog "No PSSO and OneDrive setup files found"
		fi
	fi
}

# WRITE FLAG FILE TO NOTIFY SCRIPT HAS ALREADY RUN
# -----------------------------------
write_flag() {
	updateLog "Writing flag file to notify that this script has already run"
	local currentUser=$(/usr/bin/stat -f "%Su" /dev/console)
	local flag="/Users/$currentUser/.Post_ZTP_Ran"
	
	if [[ ! -f "$flag" ]]; then
		touch "${flag}"
	fi
}

# MAIN FUNCTION
# -----------------------------------
main() {
	# Check if this script has already run
	if [[ -f "$flag" ]]; then
		updateLog "Found flag file at ${flag}. This policy has already run. Exiting"
		exit 0
	fi
	
	# Start Post ZTP
	updateLog "Running script ${script_name}"
	
	# Stop Jamf launch daemon
	stop_Jamf_launchdaemon 
	sleep 10
	
	# Check computer name
	check_computer_name
	
	# Run check if ZTP apps installed; install any that are missing
	check_ztp_apps
	
	# Run check if any failed ZTP installs were remediated
	check_remediated_apps
	
	# Install remaining apps and fonts
	check_post_ztp_apps
	
	# Write flag file
	write_flag
	
	# Start Jamf launch daemon
	start_Jamf_launchdaemon
	sleep 10
}

# RUN ALL FUNCTIONS
main "$@"

updateLog "App installs and configurations complete"
