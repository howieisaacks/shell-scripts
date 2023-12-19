#!/bin/zsh


#############################
# Checks for apps that should have been installed during ZTP and installs them if they are not installed.
# Installs fonts and the rest of the security agents.
# Font installs are defined as a function. Any font not installed will install when the function runs.
# DLP installs are scoped by region.
# The "--forceNoRecon" option is used in all install steps because all of these policies include recon.
# Recon should be ran at the end of this process, not during.
#
# Howie Isaacks | 9/11/2023
#############################

# Variables
jamfBinary="/usr/local/jamf/bin/jamf"
logFile="/private/tmp/post-ztp.log"

# Post ZTP apps
barlowFont="/Library/Fonts/BarlowCondensed-Medium.ttf"
calibreFont="/Library/Fonts/Calibre-Regular.otf"
financierFont="/Library/Fonts/FinancierDisplay-Regular.otf"
notosansFont="/Library/Fonts/NotoSansCJKjp-Regular.otf"
notoserifFont="/Library/Fonts/NotoSerifCJKjp-Regular.otf"
spacemonoFont="/Library/Fonts/SpaceMono-Regular.ttf"
aternity="/Applications/AternityAgent.app"
crowdstrike="/Applications/Falcon.app"
rapid7="/opt/rapid7/ir_agent/components/insight_agent/common/agent.log"
snapclient="/Applications/Snap Client.app"
dlp="/Library/Manufacturer/Endpoint Agent/Symantec.app"

# ZTP apps
chrome="/Applications/Google Chrome.app"
excel="/Applications/Microsoft Excel.app"
onedrive="/Applications/OneDrive.app"
onenote="/Applications/Microsoft OneNote.app"
outlook="/Applications/Microsoft Outlook.app"
powerpoint="/Applications/Microsoft PowerPoint.app"
teams="/Applications/Microsoft Teams classic.app"
word="/Applications/Microsoft Word.app"
zoom="/Applications/zoom.us.app"
carbonblack="/Applications/VMware Carbon Black Cloud/VMware CBCloud.app"
forescout="/Applications/ForeScout SecureConnector.app"
globalprotect="/Applications/GlobalProtect.app"
altiris="/Applications/Utilities/Symantec Management Agent.app"

############################# Post ZTP apps ############################# 
function Fonts () {

if [ -f "$barlowFont" ]; then
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Barlow Font is installed" >> "$logFile"
	else
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Barlow Font is NOT installed... Installing." >> "$logFile"
		$jamfBinary policy -event install-barlow --forceNoRecon
fi
if [ -f "$calibreFont" ]; then
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Calibre Font is installed" >> "$logFile"
	else
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Calibre Font NOT installed... Installing." >> "$logFile"
		$jamfBinary policy -event install-calibre --forceNoRecon
fi
if [ -f "$financierFont" ]; then
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Financier Font is installed" >> "$logFile"
	else
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Financier Font is NOT installed... Installing." >> "$logFile"
		$jamfBinary policy -event install-financier --forceNoRecon
fi
if [ -f "$notosansFont" ]; then
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Noto Sans Font is installed" >> "$logFile"
	else
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Noto Sans Font is NOT installed... Installing." >> "$logFile"
		$jamfBinary policy -event install-notosans --forceNoRecon
fi
if [ -f "$notoserifFont" ]; then
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Noto Serif Font is installed" >> "$logFile"
	else
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Noto Serif Font NOT installed... Installing." >> "$logFile"
		$jamfBinary policy -event install-notoserif --forceNoRecon
fi
if [ -f "$spacemonoFont" ]; then
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Space Mono Font is installed" >> "$logFile"
	else
	echo "$(date "+%Y-%m-%d %H:%M:%S")", "Space Mono Font is NOT installed... Installing." >> "$logFile"
		$jamfBinary policy -event install-spacemono --forceNoRecon
fi
}
# Install fonts
echo "Installing fonts if needed..."
Fonts

############################# Post ZTP apps ############################# 

# Install Aternity
if [ -d "$aternity" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "Aternity is installed" >> "$logFile"
    else
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "Aternity is NOT installed... Installing." >> "$logFile"
        "$jamfBinary" policy -event install-aternity --forceNoRecon
fi

# Install CrowdStrike
if [ -d "$crowdstrike" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "CrowdStrike is installed" >> "$logFile"
    else
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "CrowdStrike is NOT installed... Installing." >> "$logFile"
        "$jamfBinary" policy -event install-crowdstrike --forceNoRecon
fi

# Install DLP for the appropriate region
if [ -d "$dlp" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "DLP is installed" >> "$logFile"
    else
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "DLP is NOT installed... Installing." >> "$logFile"
        "$jamfBinary" policy -event dlp-us --forceNoRecon
        "$jamfBinary" policy -event dlp-emea --forceNoRecon
        "$jamfBinary" policy -event dlp-apac --forceNoRecon
fi

# Install Rapid7
if [ -d "$rapid7" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "Rapid7 is installed" >> "$logFile"
    else
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "Rapid7 is NOT installed... Installing." >> "$logFile"
        "$jamfBinary" policy -event install-rapid7-4 --forceNoRecon
fi

############################# ZTP apps ############################# 
# Install Google Chrome
if [ -d "$chrome" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Google Chrome is installed" >> "$logFile"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Google Chrome is NOT installed... Installing." >> "$logFile"
        "$jamfBinary" policy -event install-chrome --forceNoRecon
fi

# Install Microsoft Excel
    if [ -d "$excel" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Excel is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Excel is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-excel --forceNoRecon
    fi

# Install Microsoft OneDrive
    if [ -d "$onedrive" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft OneDrive is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft OneDrive is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-onedrive --forceNoRecon
    fi

# Install Microsoft OneNote
    if [ -d "$onenote" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft OneNote is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft OneNote is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-onenote --forceNoRecon
    fi

# Install Microsoft Outlook
    if [ -d "$outlook" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Outlook is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Outlook is NOT installed" >> "$logFile"
                "$jamfBinary" policy -event install-outlook --forceNoRecon
    fi

# Install Microsoft PowerPoint
    if [ -d "$powerpoint" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft PowerPoint is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft PowerPoint is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-powerpoint --forceNoRecon
    fi

# Install Microsoft Teams
    if [ -d "$teams" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Teams is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Teams is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-teams --forceNoRecon
    fi

# Install Microsoft Word
    if [ -d "$word" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Word is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Microsoft Word is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-word --forceNoRecon
    fi

# Install Zoom
    if [ -d "$zoom" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Zoom is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Zoom is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-zoom --forceNoRecon
    fi

# Install Altiris
    if [ -d "$altiris" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Symantec Management is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Symantec Management is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-symantecmanagement --forceNoRecon
    fi

# Install Carbon Black
    if [ -d "$carbonblack" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Carbon Black is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Carbon Black is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-carbonblack --forceNoRecon
    fi

# Install ForeScout
    if [ -d "$forescout" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP ForeScout is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP ForeScout is NOT installed... Installing." >> "$logFile"
                "$jamfBinary" policy -event install-forescout --forceNoRecon
    fi

# Install Global Protect
    if [ -d "$globalprotect" ]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Global Protect is installed" >> "$logFile"
else
        echo "$(date "+%Y-%m-%d %H:%M:%S")", "ZTP Global Protect is NOT installed... Installing" >> "$logFile"
                "$jamfBinary" policy -event install-globalprotect612 --forceNoRecon
    fi


############################# Run Inventory ############################# 

# Comment out this line if the policy that this script is attached to runs an inventory.
$jamfBinary recon

exit 0
