#!/bin/zsh --no-rcs

:<<ABOUT_THIS_SCRIPT
---------------------------------------------------------------------------------------------------
This script runs from the Post ZTP policy. It performs the following functions:

1 - Stops Jamf agent to prevent policies from running at check-in

2 - Runs removal of policy files from enforced macOS update if the Mac enrolled running an outdated macOS version

3 - Checks the computer name and sets to the correct name if it was not set correctly

4 - Checks if the Mac was successfully updated if it enrolled running an outdated macOS version

5 - Checks if all ZTP apps installed and installs any that are missing

6 - Installs remaining apps and company fonts

7 - Runs a check if any failed ZTP installs have been remediated

8 - Deploys Platform Single Sign-on

9 - Starts the Jamf agent

10 - Runs inventory

USE JAMF PARAMETER 4 TO SPECIFY THE REQUIRED MAJOR MACOS VERSION

VERSION 5.3
Added check for user logged in with platform single sign-on. If user is logged in PSSO will not
be deployed.

11/25/2025 | Howie Canterbury
---------------------------------------------------------------------------------------------------
ABOUT_THIS_SCRIPT

# Log function
logFile="/var/log/Post-ZTP.log"
updateLog() {
	[[ ! -f "$logFile" ]] && touch "$logFile"
	echo -e "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$logFile"
}

# Create management folder if not present - DEPRECATED
management_folder() {
	managementFolder="/usr/local/Management"
	if [ ! -d "$managementFolder" ]; then
		mkdir -p "$managementFolder"
		/bin/chmod 755 -R "$managementFolder"
	fi
}

########################################################
#                 Jamf Pro functions                   #
########################################################

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

# Check if Jamf launch daemon is running
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
	local serial=$(system_profiler SPHardwareDataType | grep Serial | /usr/bin/awk '{ print $4 }')
	local computer_name=$(hostname)
	if [[ "$computer_name" = "$serial" ]]; then
		updateLog "Computer name setting successful"
	else
		updateLog "Computer name failed to set during ZTP. Setting to "${serial}""
		"$jamfAgent" setComputerName -name "${serial}"
	fi
}

########################################################
#  macOS update enforcement during enrollment cleanup  #
########################################################

# Check for and remove files from outdated macOS enrollment policy
enrollment_update_cleanup() {
	updateLog "Looking for outdated macOS enforced update policy files and deleting them..."
	local enrollment_update=(
		"/Library/LaunchDaemons/com.cbre.enrollment.sym-auto.plist"
		"/Library/LaunchDaemons/com.cbre.macOS-Outdated.plist"
		"/usr/local/Management/macOSOutdatedAlert.sh"
		"/usr/local/Management/symLaunch.sh"
	)
	# Unload launch daemons
	if [[ $(/bin/launchctl list | grep com.cbre.enrollment.sym-auto) ]]; then
	/bin/launchctl remove "com.cbre.enrollment.sym-auto" 2>/dev/null
	fi
	
	if [[ $(/bin/launchctl list | grep ccom.cbre.macOS-Outdated) ]]; then
	/bin/launchctl remove "com.cbre.macOS-Outdated" 2>/dev/null
	fi
	
	local found_any=0
	
	# Delete policy files
	for file in "${enrollment_update[@]}"; do
		if [[ -f "$file" ]]; then
			updateLog "Found file at "$file". Deleting..."
			rm -f "$file"
			found_any=1
		fi
	done
	
	if [[ $found_any -eq 0 ]]; then
		updateLog "No policy files found"
	fi
}

##############################################################
#  Check if macOS upgrade was a success and report to PLIST  #
##############################################################

# Outdated macOS update enforcement
outdated_macos_plist="/usr/local/Management/com.cbre.outdated.macos.plist"
req_macOS="${4:-15}" # Use Jamf parameter 4 to specify required major macOS version; use 15 if not specified in the policy
current_OS=$(/usr/bin/sw_vers -productVersion)
currentOS_major=$(echo "$current_OS" | awk -F. '{print $1}')

# Write updates to outdated macOS PLIST
update_plist_outdated () {
	# Write new values only if the PLIST is present
	if [[ -f "$outdated_macos_plist" ]]; then
		# Command to set a key and value to PLIST
		/usr/libexec/PlistBuddy -c "Set :${1} ${2}" "$outdated_macos_plist"
	fi
}

# Check if macOS was updated to the required version and report
check_os() {
	updateLog "Checking if macOS has been updated to the required version"
	if [[ "$currentOS_major" -ge "$req_macOS" ]]; then
		updateLog "macOS was updated to the required version"
		update_plist_outdated FinalOS "${current_OS}"
		update_plist_outdated Remediated Yes
	else
		updateLog "macOS was not updated to the required version"
		update_plist_outdated FinalOS "${current_OS}"
		update_plist_outdated Remediated No
	fi
}

##############################################################
#    Check ZTP app installs; install any that are missing    #
#    Install remaining apps, agents, and fonts	             #
##############################################################

# ZTP PLIST
ztp_check_plist="/usr/local/Management/com.cbre.ztp.plist"
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
		"Company Portal","/Applications/Company Portal.app","install-companyportal"
		"Zoom","/Applications/zoom.us.app","install-zoom"
		"ForeScout Secure Connector","/Applications/ForeScout SecureConnector.app","install-forescout"
		"Global Protect","/Applications/GlobalProtect.app","install-globalprotect"
		"CrowdStrike","/Applications/Falcon.app","install-crowdstrike"
		"Tanium","/Library/Tanium/TaniumClient/TaniumClient","install-tanium"
	)
	
	# Count of ZTP apps
	ztp_apps=$(echo "$(( ${#app_array[@]} / 3 ))")
	echo $ztp_apps
	
	# Run checks; report status; install if needed
	updateLog "Checking if all ZTP apps installed. Will install missing apps if needed."
	for app in "${app_array[@]}"; do
		local app_name=$(echo "$app" | cut -d ',' -f1)
		local app_path=$(echo "$app" | cut -d ',' -f2)
		local install_policy=$(echo "$app" | cut -d ',' -f3)
		#updateLog "Checking ${app_name}"
		if [[ -d "$app_path" ]] || [[ -f "$app_path" ]]; then
			updateLog "${app_name} Installed"
		elif  [[ ! -d "$app_path" ]] || [[ ! -f "$app_path" ]]; then
			updateLog "${app_name} not installed. Running policy: $install_policy"
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
		"Nudge","/Applications/Utilities/Nudge.app","install-nudge"
		"Proofpoint DLP","/Library/PEA/agent/ITProtector.app","install-ppdlp"
	)
	
	# Run checks; report status; install if needed
	updateLog "Installing remaining company apps if not already installed."
	for app in "${app_array[@]}"; do
		local app_name=$(echo "$app" | cut -d ',' -f1)
		local app_path=$(echo "$app" | cut -d ',' -f2)
		local install_policy=$(echo "$app" | cut -d ',' -f3)
		#updateLog "Checking ${app_name}"
		if [[ -d "$app_path" ]] || [[ -f "$app_path" ]]; then
			updateLog "${app_name} installed"
		elif  [[ ! -d "$app_path" ]] || [[ ! -f "$app_path" ]]; then
			updateLog "${app_name} not installed. Running policy: $install_policy"
			jamfPolicy $install_policy
		fi
	done
}

##################################################################
#  	Check if failed installs (if any) were remediated and report #
##################################################################

# Check if failed app installs have been remediated
check_remediated_apps() {
	app_array=(
		"Google Chrome","/Applications/Google Chrome.app"
		"Microsoft Edge","/Applications/Microsoft Edge.app"
		"Microsoft Excel","/Applications/Microsoft Excel.app"
		"OneDrive","/Applications/OneDrive.app"
		"Microsoft OneNote","/Applications/Microsoft OneNote.app"
		"Microsoft Outlook","/Applications/Microsoft Outlook.app"
		"Microsoft PowerPoint","/Applications/Microsoft PowerPoint.app"
		"Microsoft Teams","/Applications/Microsoft Teams.app"
		"Microsoft Word","/Applications/Microsoft Word.app"
		"Company Portal","/Applications/Company Portal.app"
		"Zoom","/Applications/zoom.us.app"
		"ForeScout Secure Connector","/Applications/ForeScout SecureConnector.app"
		"Global Protect","/Applications/GlobalProtect.app"
		"CrowdStrike","/Applications/Falcon.app"
		"Tanium","/Library/Tanium/TaniumClient/TaniumClient"
	)
	
	# Count of ZTP apps
	ztp_apps=$(echo "${#app_array[@]}")
	
	updateLog "Checking that all app install failures have been remediated."
	for app in "${app_array[@]}"; do
		local app_name=$(echo "$app" | cut -d ',' -f1)
		local app_path=$(echo "$app" | cut -d ',' -f2)
		#updateLog "Checking ${app_name}"
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
}

##################################################################
#  	 				Platform Single Sign-on 					 #
##################################################################

# Check if user is registered with PSSO
check_psso_status() {
	local currentUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )
	local psso_status=$(dscl . read /Users/$currentUser dsAttrTypeStandard:AltSecurityIdentities | awk -F'SSO:' '/PlatformSSO/ {print $2}')
		
		# PSSO sign-on status
		if [[ -n "$psso_status" ]]; then
			psso_logged_in="Yes"
			username=$(echo "$psso_status")
		else
			psso_logged_in="No"
		fi
		}

# Deploy platform single sign-on
deploy_psso() {
	updateLog "Deploying Platform Single Sign-on"
	jamfPolicy "deploy-psso"
}

######################################################
#               Run the functions!	                 #
######################################################

# 1 - Stop Jamf launch daemon to prevent policies from running at check-in
	stop_Jamf_launchdaemon 

# 2 - Check for and remove enforced macOS update policy files (if the Mac enrolled with and outdated OS)
	enrollment_update_cleanup
	
# 3 - Check computer name
	check_computer_name
	
# 4 - Check if macOS was updated (if the Mac enrolled with and outdated OS)
	if [[ -f "$outdated_macos_plist" ]]; then
		check_os
	fi

# 5 - Run ZTP apps install check and install any not installed
	check_ztp_apps
	
# 6 - Run post ZTP apps check and install any not installed
	check_post_ztp_apps
	
# 7 - Run check for remediated failed ZTP apps installs
	if [[ -n "$failed_installs" ]]; then
		check_remediated_apps
	elif [[ -z "$failed_installs" ]]; then
		updateLog "No failed installs listed. Continuing..."
	fi

# 8 - Deploy Platform Single Sign-on if not registered
check_psso_status
if [[ "$psso_logged_in" == "No" ]]; then
	deploy_psso
elif [[ "$psso_logged_in" == "Yes" ]]; then
	updateLog "User is registered with PSSO"
fi
	
# 9 - Start Jamf launch daemon
	start_Jamf_launchdaemon
	
# 10 - Run inventory
	updateLog "All done! Did I leave the oven on?"
	"$jamfAgent" recon
