#!/bin/bash

####################################################################################################
#
# Display Message via swiftDialog
#
# Purpose: Displays an end-user message via swiftDialog
# See: https://snelson.us/2023/03/display-message-0-0-7-via-swiftdialog/
#
#    ____                  ____             __                                 __     __  __                  ______                      ____         
#    / __ \________        / __ \___  ____  / /___  __  ______ ___  ___  ____  / /_   / / / /_______  _____   /_  __/________ _____  _____/ __/__  _____
#   / /_/ / ___/ _ \______/ / / / _ \/ __ \/ / __ \/ / / / __ `__ \/ _ \/ __ \/ __/  / / / / ___/ _ \/ ___/    / / / ___/ __ `/ __ \/ ___/ /_/ _ \/ ___/
#  / ____/ /  /  __/_____/ /_/ /  __/ /_/ / / /_/ / /_/ / / / / / /  __/ / / / /_   / /_/ (__  )  __/ /       / / / /  / /_/ / / / (__  ) __/  __/ /    
# /_/   /_/   \___/     /_____/\___/ .___/_/\____/\__, /_/ /_/ /_/\___/_/ /_/\__/   \____/____/\___/_/       /_/ /_/   \__,_/_/ /_/____/_/  \___/_/     
#     ___         __  __          /_/           _/____/     __                                                                                          
#    /   | __  __/ /_/ /_  ____  ______        / /   |     / /                                                                                          
#   / /| |/ / / / __/ __ \/ __ \/ ___(_)  __  / / /| |__  / /                                                                                           
#  / ___ / /_/ / /_/ / / / /_/ / /  _    / /_/ / ___ / /_/ /                                                                                            
# /_/  |_\__,_/\__/_/ /_/\____/_/  (_)   \____/_/  |_\____/                                                                                             
#                                                                                                                                                      
#
####################################################################################################

####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.10"
scriptLog="/var/tmp/org.churchofjesuschrist.log"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
osVersion=$( sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
dialogBinary="/usr/local/bin/dialog"
dialogMessageLog=$( mktemp /var/tmp/dialogWelcomeLog.XXX )
if [[ -n ${4} ]]; then titleoption="--title"; title="${4}"; fi
if [[ -n ${5} ]]; then messageoption="--message"; message="${5}"; fi
if [[ -n ${6} ]]; then iconoption="--icon"; icon="${6}"; fi
if [[ -n ${7} ]]; then button1option="--button1text"; button1text="${7}"; fi
if [[ -n ${8} ]]; then button2option="--button2text"; button2text="${8}"; fi
extraflags="${10}"
action="${11}"

# Create `overlayicon` from Self Service's custom icon (thanks, @meschwartz!)
xxd -p -s 260 "$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path)"/Icon$'\r'/..namedfork/rsrc | xxd -r -p > /var/tmp/overlayicon.icns
overlayicon="/var/tmp/overlayicon.icns"

# Default icon to Jamf Pro Self Service if not specified
if [[ -z ${icon} ]]; then
    iconoption="--icon"
    icon="/var/tmp/overlayicon.icns"
fi

####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\n###\n# Display Message via swiftDialog (${scriptVersion})\n###\n"
updateScriptLog "PRE-FLIGHT CHECK: Initiating …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    updateScriptLog "PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; proceeding ..."
else
    updateScriptLog "PRE-FLIGHT CHECK: macOS ${osVersion} installed; exiting."
    osascript -e 'display dialog "Display Message via swiftDialog ('"${scriptVersion}"')\rby Dan K. Snelson (https://snelson.us)\r\rmacOS '"${osVersion}"' installed; macOS Big Sur 11\r(or later) required" buttons {"OK"} with icon caution with title "Display Message via swiftDialog: Error"'
    exit 1
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        updateScriptLog "PRE-FLIGHT CHECK: Dialog not found. Installing..."

        # Create temporary working directory
        workDirectory=$( /usr/bin/basename "$0" )
        tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

        # Download the installer package
        /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

        # Verify the download
        teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

        # Install the package if Team ID validates
        if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

            /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
            sleep 2
            dialogVersion=$( /usr/local/bin/dialog --version )
            updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} installed; proceeding..."

        else

            # Display a so-called "simple" dialog if Team ID fails to validate
            osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Display Message via Dialog: Error" buttons {"Close"} with icon caution'
            quitScript "1"

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version $(${dialogBinary} --version) found; proceeding..."

    fi

}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    dialogCheck
else
    updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version $(${dialogBinary} --version) found; proceeding..."
fi

####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Quitting …"
    echo "quit:" >> "${dialogMessageLog}"

    sleep 1
    updateScriptLog "Exiting …"

    # Remove dialogMessageLog
    if [[ -f ${dialogMessageLog} ]]; then
        updateScriptLog "Removing ${dialogMessageLog} …"
        rm "${dialogMessageLog}"
    fi

    # Remove overlayicon
    if [[ -f ${overlayicon} ]]; then
        updateScriptLog "Removing ${overlayicon} …"
        rm "${overlayicon}"
    fi

    updateScriptLog "Goodbye!"
    exit "${1}"

}

####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${title}" ]] || [[ -z "${message}" ]]; then

    updateScriptLog "Either Parameter 4 or Parameter 5 are NOT populated; displaying instructions …"

    extraflags="--width 800 --height 400 --moveable --position middle --titlefont size=26 --messagefont size=13 --iconsize 125 /var/tmp/overlayicon.icns"
    #--width 825 --height 400 --moveable --timer 75 --position topright --blurscreen --titlefont size=26 --messagefont size=13 --iconsize 125 --overlayicon /var/tmp/overlayicon.icns --quitoninfo

    titleoption="--title"
    title="Pre-Deployment User Transfer"

    messageoption="--message"
    message="Welcome to the MSU Pre-Deployment User Transfer script! \n\n- Please ensure the user's folder is already created on the new device  \n- Drag both directories into the corresponding fields  \n- Standard Library Files includes (if found): Safari, Chrome, Mozilla, Thunderbird, and the MacOS Dock  \n- Happy transferring!"

    button1option="--button1text"
    button1text="Continue"

    button2option="--button2text"
    button2text="Cancel"

    checkboxoption="--checkbox"
    checkboxtext="Include Standard Library Files"

    infobuttonoption="--infobuttontext"
    infobuttontext="Infobutton [Paramter 9]"
else

    updateScriptLog "Both \"title\" and \"message\" Parameters are populated; proceeding ..."

fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Message: Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Title: ${title}"
updateScriptLog "Message: ${message}"
updateScriptLog "Extra Flags: ${extraflags}"

function drawDialog() {
    UI=$(
    ${dialogBinary} \
        ${titleoption} "${title}" \
        ${messageoption} "${message}" \
        ${iconoption} "${icon}" \
        --textfield "Source Directory, fileselect, filetype=folder, required" \
        --textfield "Destination Directory, fileselect, filetype=folder, required" \
        ${checkboxoption} "${checkboxtext}" \
        ${button1option} "${button1text}" \
        ${button2option} "${button2text}" \
        --messagefont "size=14" \
        --commandfile "${dialogMessageLog}" \
        ${extraflags}
    )
}

completion=1
while [ $completion == 1 ]; do
    completion=0

    drawDialog
    returncode=$?
    updateScriptLog "Return Code: ${returncode}"

    case ${returncode} in

    0)  # Process exit code 0 scenario here (Continue)
        updateScriptLog "${loggedInUser} clicked ${button1text};"     

        srcDir=$(echo "$UI" | awk -F 'Source Directory : ' '{print $2}')
        destDir=$(echo "$UI" | awk -F 'Destination Directory : ' '{print $2}' | tr -d '\n')
        checkboxValue=$(echo "$UI" | awk -F'\"' '/Include Standard Library Files/ {print $4}')

        if [[ -d "${srcDir}" || -d "${destDir}" ]]; then
            ${dialogBinary} \
                --mini \
                --title "Working..." \
                --button1disabled \
                ${iconoption} "${icon}" \
                --commandfile "${dialogMessageLog}" \
                --message "Your transfer is starting..  \nPlease wait!" & sleep 0.1

            updateScriptLog "${loggedInUser} entered ${srcDir} and ${destDir};"
            completion=0
            count=0
            output=$(rsync -avr --exclude='Library' --dry-run --stats "$srcDir/" "$destDir")
            /bin/echo "quit:" >> "${dialogMessageLog}"
            number_of_files=$(echo "$output" | wc -l)
            real_number_of_files=$(echo "$output" | grep -o "Number of files transferred: [0-9]*" | awk '{print $5}')
            ${dialogBinary} \
                --title "Transfer in progress..." \
                --message "Please wait while the transfer completes  \n\n Files to be transferred: ${real_number_of_files}" \
                ${iconoption} "${icon}" \
                ${button1option} "Cancel" \
                --blurscreen \
                --button1disabled \
                --centreicon \
                --messagealignment center \
                --progress ${number_of_files} \
                --commandfile "${dialogMessageLog}" & sleep 0.1

            caffeinate -dis &
            while IFS= read -r line; do
                ((count++))
                percentage=$(expr $count \* 100 / $number_of_files)
                /bin/echo "progress: ${count}" >> "${dialogMessageLog}"
                /bin/echo "progresstext: ${percentage}% / 100%" >> "${dialogMessageLog}"
            done < <(rsync -avr --exclude='Library' --stats --no-perms "$srcDir/" "$destDir") #--dry-run flag 

            if [[ $checkboxValue == "true" ]]; then 
            /bin/echo "progresstext: Adding final library files..." >> "${dialogMessageLog}"
                if [[ -d  "$srcDir/Library/Safari" ]]; then
                    rsync -avr "$srcDir/Library/Safari" "$destDir/Library/"
                fi
                if [[ -d  "$srcDir/Library/Thunderbird" ]]; then
                    rsync -avr "$srcDir/Library/Thunderbird" "$destDir/Library/"
                fi
                if [[ -d  "$srcDir/Library/Application Support/Firefox" ]]; then
                    rsync -avr "$srcDir/Library/Application Support/Firefox" "$destDir/Library/Application Support/"
                fi
                if [[ -d  "$srcDir/Library/Application Support/Google" ]]; then
                    rsync -avr "$srcDir/Library/Application Support/Google" "$destDir/Library/Application Support/"
                fi
                if [[ -d  "$srcDir/Library/Preferences/com.apple.dock.plist" ]]; then
                    rsync -avr "$srcDir/Library/Preferences/com.apple.dock.plist" "$destDir/Library/Preferences/"
                    killall Dock
                fi                                                           
            fi

            /bin/echo "quit:" >> "${dialogMessageLog}"
            ${dialogBinary} \
                --mini \
                --title "Finished!" \
                ${iconoption} "${icon}" \
                --message "Your transfer has completed!"
            killall caffeinate

        else 
            echo "User did not enter a directory!"
            completion=1
            ${dialogBinary} \
                --mini \
                --title "ERROR!" \
                --centreicon \
                --messagealignment center \
                ${button1option} "${button1text}" \
                ${iconoption} "${icon}" \
                --message "Please enter a valid directory!"
        fi
        ;;

    2)  # Process exit code 2 scenario here (Cancel)
        echo "${loggedInUser} clicked ${button2text}"
        updateScriptLog "${loggedInUser} clicked ${button2text};"
        completion=0
        quitScript "0"
        ;;

    20) # Process exit code 20 scenario here (DND)
        echo "${loggedInUser} had Do Not Disturb enabled"
        updateScriptLog "${loggedInUser} had Do Not Disturb enabled"
        quitScript "0"
        ;;

    *)  # Catch all processing (Other occurances)
        echo "Something else happened; Exit code: ${returncode}"
        updateScriptLog "Something else happened; Exit code: ${returncode};"
        quitScript "${returncode}"
        ;;

    esac
done

updateScriptLog "End-of-line."

quitScript "0"