#!/bin/bash
####################################################################################################
#
# Copyright (c) 2015, JAMF Software, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
##############
#
#  CSV must have two columns and no header      Serial number then Asset Tag
#
############################################################


#####Ask for JSS API Username
display dialog "Enter username for JSS API :" default answer "Username"
set your_user to text returned of result

######Ask for JSS API Password
display dialog "Enter password for JSS API" default answer "Password" with icon stop with hidden answer
set your_password to text returned of result

#######Ask for JSS Address
display dialog "Enter JSS Address with NO ending Slash:" default answer "https://myjss.com:8443"
set your_jss to text returned of result

####################################VERIFY ##########
#######check if user can log in to jss API -- has 10 second timeout
set apiacct to "curl --connect-timeout 10 -ksu " & your_user & ":" & your_password & " " & your_jss & "/JSSResource/accounts/username/" & your_user & " | xpath /account/name[1] | sed 's,<name>,,;s,</name>,,' | tail -1"
set apiuserrun to do shell script apiacct
#display dialog apiuserrun
if apiuserrun = "" then
	display dialog "The user account or password was wrong, or doesn't have API Rights"
	exit repeat
else
	display dialog "User " & apiuserrun & " exists on JSS and can query API. This process will start once button is clicked and can take quite a few minutes depending on how many devices." buttons {"Roger That"}
	
	####################################################################################################
	
	######Looking for Path
	set theFile to (choose file with prompt "Select the CSV file that contains serial Number and asset tag")
	
	### Read the Data
	set f to read theFile
	
	#### Break data into rows
	repeat with row in (paragraphs of f)
		
		####parse from comma Delimited 
		set fields to parseCSV(row as text)
		
		####Set Rows for Data Fields
		set serial to item 1 of fields
		set asset to item 2 of fields
		
		
		#### Display each one, should comment out or Delete once done testing
		#####display dialog "Serial Number:  " & serial & "     " & "Asset Tag:  " & asset
		
		
		
		####get ID of Device, Since Serial Numbers doesn't have put or post
		set idnum to do shell script "curl -k -s -u " & your_user & ":" & your_password & " " & your_jss & "/JSSResource/mobiledevices/serialnumber/" & serial & " | xpath /mobile_device/general/id[1] | sed 's,<id>,,;s,</id>,,' | tail -1"
		
		######checking if Asset Matches
		
		############get Variable to see if record already has asset tag
		set gdstf to "curl -k -s -u " & your_user & ":" & your_password & " " & your_jss & "/JSSResource/mobiledevices/serialnumber/" & serial & " | xpath /mobile_device/general/asset_tag[1] | sed 's,<asset_tag>,,;s,</asset_tag>,,' | tail -1"
		
		
		####display dialog (do shell script gdstf)
		set jssasset to do shell script gdstf
		
		
		########TESTING SPOT
		#display dialog jssasset
		
		##########checking if Asset from JSS is blank first
		
		if jssasset contains "asset_tag" then
			
			###writing to JSS API the Asset Tag
			
			####testing Display option
			####display dialog "writing to JSS hopefully"
			
			##### Setting Variable for xml file with asset variable
			set dd to quoted form of "<mobile_device><general><asset_tag>" & asset & quoted form of "</asset_tag></general></mobile_device>"
			
			###### This creates the XML file that will be imported
			do shell script "echo " & dd & " > /tmp/asset.xml"
			
			###########This Writes the XML and loops
			do shell script "curl -k -s -u " & your_user & ":" & your_password & " " & your_jss & "/JSSResource/mobiledevices/id/" & idnum & " -T /tmp/asset.xml -X PUT"
			
			
			######## for Testing purposes only, leave commented out in production
			####display dialog "curl -k -s -u " & your_user & ":" & your_password & " " & your_jss & "/JSSResource/mobiledevices/id/" & idnum & " -T /tmp/asset.xml -X PUT"
		else
			#####checks to see if Matches JSS, if not writes a log to desktop, if does just goes on to next record
			if jssasset is not equal to asset then
				do shell script "echo `date`" & " >> ~/Desktop/mismatchIOS.txt"
				do shell script "echo " & " This Serial Number: " & serial & "  Reports from JSS with this asset tag:   " & jssasset & " but the Form shows this asset tag: " & asset & " >> ~/Desktop/mismatchIOS.txt"
				do shell script "echo '        ' >> ~/Desktop/mismatchIOS.txt"
				#display dialog "already exists "
				
			end if
		end if
		#### stop Loop once done
	end repeat
	display dialog "UPLOAD COMPLETE" buttons {"OK"}
end if
#####needed for parseing the CSV
on parseCSV(theText)
	set {od, my text item delimiters} to {my text item delimiters, ","}
	set parsedText to text items of theText
	set my text item delimiters to od
	return parsedText
end parseCSV




