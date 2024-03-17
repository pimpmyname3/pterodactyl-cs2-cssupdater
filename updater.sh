#!/bin/bash

# Adjust the following variables to your needs
# SFTP_USERS: An array of Pterodactyl server users to transfer the files to
SFTP_USERS=("example.11111111" "example.22222222" "example.33333333")
SFTP_PASS="PASSWORD"
SFTP_HOST="HOST"
SFTP_PORT="PORT"
SFTP_COPY_FOLDER_FROM_LOCAL="/home/exampleuser/pterodactyl-cs2-cssupdater" # Path to the folder where the updater.sh script is located

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
    echo "$DATE - Update completed." | tee -a $LOG_FILE
else
    echo "$DATE - Local version (v$LOCAL_VERSION) is up-to-date. Skipping transfer process." | tee -a $LOG_FILE
fi

# Find and remove .zip files that are at least 7 days old
OLD_FILES=$(find $SFTP_COPY_FOLDER_FROM_LOCAL -name "*.zip" -type f -mtime +7)
if [ -z "$OLD_FILES" ]
then
    echo "$DATE - No old .zip files found to remove" | tee -a $LOG_FILE
else
    echo "$DATE - Removing old .zip files: $OLD_FILES" | tee -a $LOG_FILE
    echo $OLD_FILES | xargs rm -rf
fi