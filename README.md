# CS2 Pterodactyl - CounterStrikeSharp Auto-Updater

This script is designed to automatically update a local version of CounterStrikeSharp with **runtime build** GitHub repository. It checks the latest release from the GitHub API, compares it with the local version, and if the local version is outdated, it downloads and extracts the latest release. The script also transfers the updated files to a server via SFTP. It is intended to be run as a cron job and is specifically designed for Pterodactyl CS2 game servers, but can be adapted for other use cases.

## Table of Contents
- [Installation by terminal](#installation-by-terminal)
- [How to automate the process?](#how-to-automate-the-process)
- [How to use the script](#how-to-use-the-script)
- [How to set up a cron job to run the script automatically](#how-to-set-up-a-cron-job-to-run-the-script-automatically)
- [What the script does](#what-the-script-does)

## Installation by terminal
This will install the script and all the required dependencies.
```bash
# With git
apt-get update && apt-get install git curl jq unzip sshpass && git clone https://github.com/pimpmyname3/pterodactyl-cs2-cssupdater.git && cd pterodactyl-cs2-cssupdater && chmod +x updater.sh
# OR Without git
apt-get update && apt-get install curl jq unzip sshpass && wget https://raw.githubusercontent.com/pimpmyname3/pterodactyl-cs2-cssupdater/main/updater.sh && mkdir pterodactyl-cs2-cssupdater && mv updater.sh pterodactyl-cs2-cssupdater && cd pterodactyl-cs2-cssupdater && chmod +x updater.sh
```

## How to use the script

1. Follow the installation instructions above to install the script and all the required dependencies.
2. Make the script executable with the command `chmod +x updater.sh`.
3. Run the `updater.sh` file in the terminal. For example, `bash updater.sh`.
4. On the first run, the script will prompt you to enter the following details:
    - `SFTP_USERS`: An array of SFTP usernames. These are the users for whom the updated files will be transferred to the server.
    - `SFTP_PASS`: The password for the SFTP user.
    - `SFTP_HOST`: The hostname of the SFTP server.
    - `SFTP_PORT`: The port number of the SFTP server.
    - `SFTP_COPY_FOLDER_FROM_LOCAL`: Path to the folder where the updater.sh script is located. If you want to use the current directory, just press Enter. The path has to end without a `/`. For example `/home/exampleuser/pterodactyl-cs2-cssupdater`. Very important to change this to the correct path.
    - `CLEANUP_OLD_FILES`: Set to `true` to enable the cleanup of old .zip files in the local directory. Set to `false` to disable this feature.
    - `MOUNTPOINT_USAGE`: Set to yes if you want to use the mountpoint feature. Set to no if you don't want to use the mountpoint feature. If you set it to yes, you will be asked prompts specified below. Default value is no.
    - `MOUNTPOINT_PATH`: The path to the mountpoint where the addons folder is located. For example `/srv/Mountpoint`. Very important to change this to the correct path. It has to end without a `/`. Do not use for example `/srv/Mountpoint/addons` as the path.
    - `MOUNTPOINT_USER`: The SFTP user of the mountpoint. For example `updater`.
    - `MOUNTPOINT_GROUP`: The SFTP group of the mountpoint. For example `pterodactyl`. This group has to be the same as the group of the pterodactyl user. This is used to set the correct permissions for the mountpoint user, which is required for the mountpoint feature to work correctly.
    - `MOUNTPOINT_PASS`: The SFTP password of the mountpoint user.
    - `MOUNTPOINT_HOST`: The SFTP hostname of the mountpoint.
    - `MOUNTPOINT_PORT`: The SFTP port number of the mountpoint.

5. After entering these details, the script will save them to a `config.cfg` file and then exit. You can now run the script again to use the saved configuration.
6. Install the required dependencies with the command `apt-get install curl jq unzip sshpass`.
7. Stop the servers you want to update.
8. Set up a cron job to run the script automatically (optional).
9. Run the script with the command `bash updater.sh`.

On subsequent runs, the script will read the details from the `config.cfg` file. If you need to change these details, you can either edit the `config.cfg` file directly or delete it and run the script again to enter new details.

If using the mountpoint feature, make sure to have the mountpoint setup correctly and the mountpoint user has the correct permissions to access the mountpoint. The mountpoint user should have read and write permissions to the mountpoint and must be a part of the `pterodactyl` group. This can be done by running the following command:
```bash
chmod -R 775 /srv/Mountpoint && chown -R updater:pterodactyl /srv/Mountpoint && chgrp -R pterodactyl /srv/Mountpoint && usermod -a -G pterodactyl updater
```

## How to automate the process?

You can automate the process by setting up a cron job to run the script at a specific time every day. This will ensure that the script checks for updates and updates the local version automatically. Set Schedules for each server to stop and start at a specific time and then run the script at a specific time. This will ensure that the server is stopped when the script is running and then started again after the script has finished.

## How to set up a cron job to run the script automatically.
Run the following command to open the crontab file in a text editor:
```bash
crontab -e
```
Add the following line to the crontab file to run the script every day at 3:00 AM(for example):
```bash
0 3 * * * /home/exampleuser/pterodactyl-cs2-cssupdater/updater.sh # Change this path to the location of your updater.sh file
```
Save the crontab file by pressing `Ctrl + X`, then `Y`, and then `Enter`. The script will now run automatically at the specified time.

## What the script does

1. Checks if the local version file exists. If not, it creates one with a default version of 0.
2. Fetches the latest release data from the GitHub API.
3. Extracts the version number from the release tag.
4. Reads the local version from the file.
5. Compares the local version with the latest version.
6. If the local version is outdated, it:
    - Logs the update process.
    - Downloads and extracts the latest release.
    - Updates the local version file.
    - Transfers the updated files to the server for each SFTP user.
7. If the local version is up-to-date, it skips the update process.
8. Finds and removes .zip files in the local directory that are at least 7 days old.