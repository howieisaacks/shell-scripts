#!/bin/zsh --no-rcs

:<<ABOUT_THIS_SCRIPT
--------------------------------------------------------------------------------------
Assigns a Mac to a specific site in Jamf Pro.

Under Jamf Pro API Login, specify your Jamf URL, API client ID and client secret.
Use Jamf parameter 4 for API client ID.
Use Jamf parameter 5 for API client secret. 

Get site ID from Settings - Sites - Select the site you want.
Use Jamf parameter 7 for site ID.
Use Jamf parameter 8 for site name.


This script uses an API client created in Settings - API roles and clients.
To verify login information, specify "yes" for the "verify" variable. The output
from the API login will be displayed in the policy log in Jamf Pro.

11/27/2025 | Howie Canterbury
--------------------------------------------------------------------------------------
ABOUT_THIS_SCRIPT

###############################################################################
#                            JAMF PRO API LOGIN	                              #
#             Parameter 4: API client ID                                      #
#			  Parameter 5: API client secret								  #
#   		  Parameter 6: Enter "yes" to validate API login                  #	
###############################################################################

# Jamf Pro API login
url="https://your.server"
client_id="$4"
client_secret="$5"
verify="$6"

# Jamf API authentication function
jamfAPI_auth() {
	response=$(curl --silent --location --request POST "${url}/api/oauth/token" \
		--header "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode "client_id=${client_id}" \
		--data-urlencode "grant_type=client_credentials" \
		--data-urlencode "client_secret=${client_secret}")
	token=$(echo "$response" | plutil -extract access_token raw -)
	token_expires_in=$(echo "$response" | plutil -extract expires_in raw -)
	token_expiration_epoch=$(($current_epoch + $token_expires_in - 1))
}

# Start authenticated API session
jamfAPI_auth

###############################################################################
#                            VALIDATE API LOGIN							      #
#    The token and expiration time will be echoed into the script output	  #	
#    to verify that the API login credentials provided are working.			  #
###############################################################################

if [[ "$verify" == "yes" ]]; then
	echo "API token: ${token}"
	echo "Token expires in: ${token_expires_in} seconds"
fi

# Site variables
site_id="$7" # Use Jamf parameter 6 or specify the site ID here.
site_name="$8" # Use Jamf parameter 7 or specify the site name here.
site_xml="/private/tmp/site.xml"

# Function - Create site XML file
function siteXML() {
	echo "Writing site assignment XML to /private/tmp/site.xml"
	tee "$site_xml" << EOF
<computer>
	<general>
		<site>
			<id>$site_id</id>
			<name>$site_name</name>
		</site>
	</general>
</computer>
EOF
}

# Determine Jamf Pro device id
echo "Getting the Jamf Pro device ID..."
# Computer serial number
serialNumber=$(system_profiler SPHardwareDataType | grep Serial | /usr/bin/awk '{ print $4 }')
deviceID=$(curl -s -H "Accept: text/xml" -H "Authorization: Bearer ${token}" ${url}/JSSResource/computers/serialnumber/"$serialNumber" | xmllint --xpath '/computer/general/id/text()' -)

echo "Device ID: $deviceID"

# Create the site XML file - run the function
siteXML 

# Assign Mac to the site.
echo "Assigning Mac to "$site_name" site."
curl -sfk -H "Accept: text/xml" -H "Authorization: Bearer ${token}" "${url}/JSSResource/computers/id/${deviceID}" -T "$site_xml" -X PUT

# Remove the site XML file
echo "Removing the site XML file from /private/tmp."
rm "$site_xml"
