#!/bin/bash

# Adjust the following variables to your needs
# SFTP_USERS: An array of Pterodactyl server users to transfer the files to
SCRIPT_DIR=$(dirname "$0")
CONFIG_FILE="$SCRIPT_DIR/config.cfg"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Creating a new located at $CONFIG_FILE"
    # Prompt for the variables
    echo "Enter SFTP Pterodactyl users (space-separated). example: example.11111111 example.22222222 example.33333333 :"
    read -a SFTP_USERS
    echo "Enter SFTP Pterodactyl password:"
    read SFTP_PASS
    echo "Enter SFTP Pterodactyl host:"
    read SFTP_HOST
    echo "Enter SFTP Pterodactyl port:"
    read SFTP_PORT
    echo "Enter the path of the local folder you want to copy from. If you want to use the current directory ($PWD), just press Enter:" # Path to the folder where the updater.sh script is located. Has to end without a /
    read SFTP_COPY_FOLDER_FROM_LOCAL
    # If the user didn't enter anything, use the current directory as the default value
    if [[ -z "$SFTP_COPY_FOLDER_FROM_LOCAL" ]]; then
        SFTP_COPY_FOLDER_FROM_LOCAL="$PWD"
    fi

    # Check if the updater.sh file exists in the specified directory
    if [ ! -f "$SFTP_COPY_FOLDER_FROM_LOCAL/updater.sh" ]; then
        echo "The updater.sh file was not found in the specified directory. Please make sure the directory is correct and try again."
        exit 1
    fi

    # Ask if the user wants to clean up old .zip files
    echo "Do you want to clean up old .zip files? (true/false, default is false):"
    read -p "" -e -i "false" CLEANUP_OLD_FILES

    # Using Mountpoint ?
    echo "Are you planning to upload files to a mountpoint? (yes/no, default is no). Press Enter to accept the default:"
    read -p "" -e -i "no" MOUNTPOINT_USAGE

    # If response was 'yes', gather more details
    if [ "$MOUNTPOINT_USAGE" = "yes" ]
    then
        echo "Enter the mountpoint path:"
        read MOUNTPOINT_PATH
        echo "Enter the SFTP user:"
        read MOUNTPOINT_USER
        echo "Enter the group that should own the files to set the correct permissions. (default is pterodactyl, if you are using a different group, please enter it):"
        read -p "" -e -i "pterodactyl" MOUNTPOINT_GROUP
        echo "Enter the SFTP password:"
        read MOUNTPOINT_PASS
        echo "Enter the SFTP host:"
        read MOUNTPOINT_HOST
        echo "Enter the SFTP port. (default is 22, if you are using a different port, please enter it)"
        read -p "" -e -i "22" MOUNTPOINT_PORT
    fi

    # Save the variables to the config file
    echo "SFTP_USERS=(${SFTP_USERS[@]})" > $CONFIG_FILE
    echo "SFTP_PASS=$SFTP_PASS" >> $CONFIG_FILE
    echo "SFTP_HOST=$SFTP_HOST" >> $CONFIG_FILE
    echo "SFTP_PORT=$SFTP_PORT" >> $CONFIG_FILE
    echo "SFTP_COPY_FOLDER_FROM_LOCAL=$SFTP_COPY_FOLDER_FROM_LOCAL" >> $CONFIG_FILE
    echo "CLEANUP_OLD_FILES=$CLEANUP_OLD_FILES" >> $CONFIG_FILE
    echo "MOUNTPOINT_USAGE=$MOUNTPOINT_USAGE" >> $CONFIG_FILE
    if [ "$MOUNTPOINT_USAGE" = "yes" ]
    then
        echo "MOUNTPOINT_PATH=$MOUNTPOINT_PATH" >> $CONFIG_FILE
        echo "MOUNTPOINT_USER=$MOUNTPOINT_USER" >> $CONFIG_FILE
        echo "MOUNTPOINT_GROUP=$MOUNTPOINT_GROUP" >> $CONFIG_FILE
        echo "MOUNTPOINT_PASS=$MOUNTPOINT_PASS" >> $CONFIG_FILE
        echo "MOUNTPOINT_HOST=$MOUNTPOINT_HOST" >> $CONFIG_FILE
        echo "MOUNTPOINT_PORT=$MOUNTPOINT_PORT" >> $CONFIG_FILE
    fi
    # Exit the script
    echo "Configuration saved. You can now run the script again to use the saved configuration."
    exit 0
else
    # Read the variables from the config file
    echo "Reading configuration from the config file located at $CONFIG_FILE"
    source $CONFIG_FILE
fi

# Check if all the variables are set
if [[ -z "$SFTP_USERS" || -z "$SFTP_PASS" || -z "$SFTP_HOST" || -z "$SFTP_PORT" || -z "$SFTP_COPY_FOLDER_FROM_LOCAL" || -z "$CLEANUP_OLD_FILES" || -z "$MOUNTPOINT_USAGE" ]]; then
    echo "One or more variables are not set in the config file. Please delete the config file and run the script again."
    exit 1
fi

# Check if the mountpoint is set to true and check if all the variables are set
if [ "$MOUNTPOINT_USAGE" = "yes" ]
then
    if [[ -z "$MOUNTPOINT_PATH" || -z "$MOUNTPOINT_USER" || -z "$MOUNTPOINT_GROUP" || -z "$MOUNTPOINT_PASS" || -z "$MOUNTPOINT_HOST" || -z "$MOUNTPOINT_PORT" ]]; then
        echo "One or more mountpoint variables are not set in the config file. Please delete the config file and run the script again."
        exit 1
    fi
fi

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install it first."
    exit 1
fi

# Ignore the rest below this line
# Set the log file
LOG_FILE="$SFTP_COPY_FOLDER_FROM_LOCAL/updater.log"
echo "--------------------------------------------------" | tee -a $LOG_FILE
# Set your GitHub username, repository, and the path to the local version file
GITHUB_USER="roflmuffin"
GITHUB_REPO="CounterStrikeSharp"
LOCAL_VERSION_FILE="$SFTP_COPY_FOLDER_FROM_LOCAL/version.txt"

# Check if the version file exists, if not, create it with a default version of 0
if [ ! -f "$LOCAL_VERSION_FILE" ]; then
    echo "0" > $LOCAL_VERSION_FILE
fi

# Get the latest release from GitHub API
RELEASE_DATA=$(curl --silent "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest")

# Check if curl was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch the latest release from GitHub. Please check your internet connection."
    exit 1
fi

# Extract the version number from the release tag
LATEST_RELEASE=$(echo $RELEASE_DATA | jq -r .tag_name)
LATEST_VERSION=${LATEST_RELEASE#*v}

# Read the local version from the file
LOCAL_VERSION=$(cat $LOCAL_VERSION_FILE)

# Get the current date and time
DATE=$(date +"%Y-%m-%d %H:%M")

# Compare the versions
if [ "$LOCAL_VERSION" -lt "$LATEST_VERSION" ]; then
    echo "$DATE - Local version (v$LOCAL_VERSION) is outdated. Latest is v$LATEST_VERSION. Updating..." | tee -a $LOG_FILE

    # Get the download URL of the zip file. Download and extract
    DOWNLOAD_URL=$(echo $RELEASE_DATA | jq -r '.assets[] | select(.name | contains("linux") and contains("runtime")) | .browser_download_url')
    curl -LO "$DOWNLOAD_URL"
    echo "$DATE - Extracting files" | tee -a $LOG_FILE
    unzip -oqq "${DOWNLOAD_URL##*/}"
    echo "$DATE - Files extracted" | tee -a $LOG_FILE

    # Update the local version file
    echo $LATEST_VERSION > $LOCAL_VERSION_FILE

    # Transfer the files to the server
    echo "$DATE - Transferring files to the server" | tee -a $LOG_FILE
    SFTP_COPY_FOLDER_TO_REMOTE="/game/csgo"
    SFTP_COPY_VERSION_FILE_LOCAL="$LOCAL_VERSION_FILE"
    SFTP_COPY_VERSION_FILE_REMOTE="/game/csgo/addons/cssversion.txt"

    # Loop over each user
    for SFTP_USER in "${SFTP_USERS[@]}"
    do
        echo "$DATE - Starting transfer for user: $SFTP_USER" | tee -a $LOG_FILE
        # Use sshpass with sftp to copy the folder
        if sshpass -p $SFTP_PASS sftp -o StrictHostKeyChecking=no -oPort=$SFTP_PORT $SFTP_USER@$SFTP_HOST <<EOF
        put -r $SFTP_COPY_FOLDER_FROM_LOCAL/addons $SFTP_COPY_FOLDER_TO_REMOTE
        put $SFTP_COPY_VERSION_FILE_LOCAL $SFTP_COPY_VERSION_FILE_REMOTE
        exit
EOF
        then
            echo "$DATE - Transfer for user $SFTP_USER succeeded" | tee -a $LOG_FILE
        else
            echo "$DATE - Transfer for user $SFTP_USER failed" | tee -a $LOG_FILE
        fi
    done

    # Transfer the files to the mountpoint if MOUNTPOINT_USAGE is set to yes
    if [ "$MOUNTPOINT_USAGE" = "yes" ]
    then
        echo "$DATE - Starting transfer for mountpoint" | tee -a $LOG_FILE
        # Use sshpass with sftp to copy the folder
        if sshpass -p $MOUNTPOINT_PASS sftp -o StrictHostKeyChecking=no -oPort=$MOUNTPOINT_PORT $MOUNTPOINT_USER@$MOUNTPOINT_HOST <<EOF
        put -r $SFTP_COPY_FOLDER_FROM_LOCAL/addons $MOUNTPOINT_PATH
        put $SFTP_COPY_VERSION_FILE_LOCAL $MOUNTPOINT_PATH/cssversion.txt
        exit
EOF
        then
            echo "$DATE - Transfer for mountpoint succeeded" | tee -a $LOG_FILE
        else
            echo "$DATE - Transfer for mountpoint failed" | tee -a $LOG_FILE
        fi
        # Set the correct permissions for the files. Respecting that the user doesnt have sudo rights
        if sshpass -p $MOUNTPOINT_PASS ssh -o StrictHostKeyChecking=no -oPort=$MOUNTPOINT_PORT $MOUNTPOINT_USER@$MOUNTPOINT_HOST <<EOF
        chgrp -hR $MOUNTPOINT_GROUP $MOUNTPOINT_PATH
        chmod -R 775 $MOUNTPOINT_PATH
        chown -R $MOUNTPOINT_USER:$MOUNTPOINT_GROUP $MOUNTPOINT_PATH
        exit
EOF
        then
            echo "$DATE - Permissions has successfully been set for the mountpoint" | tee -a $LOG_FILE
        else
            echo "$DATE - Failed to set permissions for the mountpoint" | tee -a $LOG_FILE
        fi
    fi
    echo "$DATE - Update completed." | tee -a $LOG_FILE
else
    echo "$DATE - Local version (v$LOCAL_VERSION) is up-to-date. Skipping transfer process." | tee -a $LOG_FILE
fi

# Find and remove .zip files containing "counterstrikesharp" that are at least 7 days old, if CLEANUP_OLD_FILES is true
if [ "$CLEANUP_OLD_FILES" = true ]
then
    OLD_FILES=$(find $SFTP_COPY_FOLDER_FROM_LOCAL -name "*counterstrikesharp*.zip" -type f -mtime +7)
    if [ -z "$OLD_FILES" ]
    then
        echo "$DATE - No old .zip files containing 'counterstrikesharp' found to remove" | tee -a $LOG_FILE
    else
        echo "$DATE - Removing old .zip files containing 'counterstrikesharp': $OLD_FILES" | tee -a $LOG_FILE
        find $SFTP_COPY_FOLDER_FROM_LOCAL -name "*counterstrikesharp*.zip" -type f -mtime +7 -delete
    fi
else
    echo "$DATE - CLEANUP_OLD_FILES is set to false, no old .zip files containing 'counterstrikesharp' will be removed" | tee -a $LOG_FILE
fi