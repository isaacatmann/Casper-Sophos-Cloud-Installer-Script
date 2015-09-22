#!/bin/bash
## postinstall

# Created By Mann Consulting - 2015
# Last Update: 
# 6/22/2015 - Will Green - Modify installation codeblock to pipe outout to logfile and send relivant run to JSS
# 4/27/2015 - Isaac Ordonez - Remove Sophos Anti-Virus.localized is detected 
# 3/30/2015 - Isaac Ordonez - Added headers and notes.
# 3/15/2015 - Lee Rahn - Identified installing after zip command caused machine to kernel 
# panic.  Used ditto to unzip the archive to resolve.

# ToDo

# Summary
# This script will automatically download and install Sophos Cloud without the need for a 
# Distribution Point of any kind.  The script will detect previous versions of Sophos 8 or
# Sophos 9 and uninstall if necessary. 

# Usage
# Upload the raw script to your JSS and set Parameter 4 label to "Sophos Download URL"
# When creating a policy to run the script copy the download URL for your
# Sophos Cloud installer.  You can find this by logging into https://cloud.sophos.com/
# choosing downloads in the upper right hand corner and copying the URL for the
# Mac OS X Installer link.  It should look something like 
# https://dzr-api-amzn-us-west-2-fa88.api-upe.p.hmr.sophos.com/api/download/98708d7508734987a9879a87263948d76298/SophosInstall.zip

#Exit Codes:
# 0 = Sucessful
# 1 = Installer Failed too many times, or a generic failure not defined by the script
# 2 = Variable 4 Not Set

### Variables & Arguments ###
pathToScript=$0
pathToPackage=$1
targetLocation=$2
targetVolume=$3


if [[ $4 == "" ]]; then
        echo "FATAL: Variable 4 not set! You must provide the Sophos Download URL for variable 4."
        exit 2
fi

if [[ $5 == "" ]]; then
        echo "WARN: Variable 5 (Max Install Attempts) not set! Using default of 3."
        MaxSAVInstallAttempts=3
    else   
        MaxSAVInstallAttempts="$5"
fi

if [[ $6 == "" ]]; then
        echo "WARN: Variable 6 (Sophos Installer Log Path) not set! Using default of /tmp/SophosAVInstallerLog.log"
        SAVInstallLog="/tmp/SophosAVInstallerLog.log"
    else   
        SAVInstallLog="$5"
fi

### Main Script ###

# Remove Sophos 8 if uninstaller is available

if [ -d "/Library/Sophos Anti-Virus/Remove Sophos Anti-Virus.pkg" ]; then
	echo "Removing old Sophos 8 installation..."
    sudo defaults write /Library/Preferences/com.sophos.sav TamperProtectionEnabled -bool false
	installer -pkg "/Library/Sophos Anti-Virus/Remove Sophos Anti-Virus.pkg" -target /
fi

# Remove Sophos 9 if uninstaller is available in opm-sa

if [ -e "/Library/Application Support/Sophos/opm-sa/Installer.app/Contents/MacOS/InstallationDeployer" ]; then
    echo "Removing old Sophos 9 installation..."
	sudo defaults write /Library/Preferences/com.sophos.sav TamperProtectionEnabled -bool false
	"/Library/Application Support/Sophos/opm-sa/Installer.app/Contents/MacOS/InstallationDeployer" --force_remove
fi

# Remove Sophos 9 if uninstaller is available in saas
if [ -e "/Library/Application Support/Sophos/saas/Installer.app/Contents/MacOS/tools/InstallationDeployer" ]; then
    echo "Removing old Sophos 9 installation..."
	sudo defaults write /Library/Preferences/com.sophos.sav TamperProtectionEnabled -bool false
	"/Library/Application Support/Sophos/saas/Installer.app/Contents/MacOS/tools/InstallationDeployer" --force_remove
fi

# Sometimes Sophos uninstaller leaves junk behind causing casper to incorrectly report version.  Remove this file if detected.
if [ -d "/Applications/Sophos Anti-Virus.localized" ]; then
	rm -R "/Applications/Sophos Anti-Virus.localized"
fi

# Download and unzip the Installer to /tmp

echo "Downloading and Unpacking Installer...

"
sudo curl -o /tmp/SophosInstall.zip "$4"
sudo ditto -xk /tmp/SophosInstall.zip /tmp
sudo rm /tmp/SophosInstall.zip

# Run Sophos Cloud Installer from /Users/Shared/
sudo chmod +x /tmp/Sophos\ Installer.app/Contents/MacOS/Sophos\ Installer

SAVInstallAttempts=0
while [[ $SAVInstallAttempts -lt $MaxSAVInstallAttempts ]]; do
    
    # Run the Installer, pipe the output to $SAVInstallLog (overwriting any contents), and immediately save the exit code as a variable so it isn't overwritten by subsequent commands
    echo "Running Installer..."
    sudo /tmp/Sophos\ Installer.app/Contents/MacOS/Sophos\ Installer --install &> "$SAVInstallLog"
    SAVInstallExitCode="$?"
    echo "Sophos installer exited with code $SAVInstallExitCode"
    
    #  If the install was sucessful, dump the log output and exit with a sucessful code
    if [[ $SAVInstallExitCode == 0 ]]; then
        echo "SAV install appears sucessful! Installer output:"
        echo $(cat "$SAVInstallLog")
        echo "-------

        Install appears to be sucessful. Review the log output above for details. Exiting!"
        exit 0
    
    # If it failed, increment $SAVInstallAttempts, and retry
    elif [[ $SAVInstallExitCode -ge 1 ]]; then
        let SAVInstallAttempts=$SAVInstallAttempts+1
        echo "WARN: The Sophos install was unsuccessful."
        echo "-------

        "
    fi
done

# If we're down here, then the installer failed too often. Log and exit.
echo "FATAL: The Sophos installer has failed too many times."
echo "Detailed logs are on the client at /var/log/installer.log. Less detailed logs below:"
echo $(cat "$SAVInstallLog")
echo "-------

"
echo "The install has failed. Exiting."
exit 1
