#!/bin/zsh

###########################
# Assigns a Mac to a specific site. 
# Use Jamf parameter 4 for site ID.
# Use Jamf parameter 5 for site name.
# Under API Login, specify the API username and password.
#
# 4/10/24 | Howie Isaacks
###########################


# API login
jamfProURL="https://YourServer.jamfcloud.com"
username="API_User"
password="SuperDuperSecretPassword"

# Computer serial number
serialNumber=$(system_profiler SPHardwareDataType | grep Serial | /usr/bin/awk '{ print $4 }')

# Request auth token
authToken=$( /usr/bin/curl \
--request POST \
--silent \
--url "$jamfProURL/api/v1/auth/token" \
--user "$username:$password" )

# Parse auth token
token=$( /usr/bin/plutil \
-extract token raw - <<< "$authToken" )

tokenExpiration=$( /usr/bin/plutil \
-extract expires raw - <<< "$authToken" )

localTokenExpirationEpoch=$( TZ=GMT /bin/date -j \
-f "%Y-%m-%dT%T" "$tokenExpiration" \
+"%s" 2> /dev/null )

# Site variables
site_id="$4"
site_name="$5"
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
deviceID=$(curl -s -H "Accept: text/xml" -H "Authorization: Bearer ${token}" ${jamfProURL}/JSSResource/computers/serialnumber/"$serialNumber" | xmllint --xpath '/computer/general/id/text()' -)

echo "Device ID: $deviceID"

# Create the site XML file - run the function
siteXML 

# Assign Mac to the site.
echo "Assigning Mac to "$site_name" site."
curl -sfk -H "Accept: text/xml" -H "Authorization: Bearer ${token}" "${jamfProURL}/JSSResource/computers/id/${deviceID}" -T "$site_xml" -X PUT

# Remove the site XML file
echo "Removing the site XML file from /private/tmp."
rm "$site_xml"