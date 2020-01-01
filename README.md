# SPSB

A **S**imple **P**ower**S**hell **B**ackup script.

## Abstract

The script aims at backing up a whole folder or a single file as archive or
synchronizing the contents of a directory from a Windows machine to a network
share (Samba). It's intended to be run regularly as a scheduled task or at
system events like user log off or system shutdown.

## Configuration

It's necessary to manually modify the variables at the beginning of the script
to provide some real host and user names and passwords.

### Setting up script execution with Task Scheduler

To setup the script for execution at specific time do the following:

1. Go to Start Menu -> Run (or press Win Key + R).
2. Type `taskschd.msc` and hit enter to open Task Scheduler.
3. Go to Action -> Create Task...
4. Enter task name (e.g. Backup) and description (e.g. Backup files and folders
   from this computer to a network share) on tab General in the dialog and
   choose Security options.
5. Go to Triggers and add scheduling by clicking on New... button.
6. Then go to Actions and click on New... button.
7. Select Start a program in Action and select the script in Program/script.
8. Eventually choose other options on Conditions and Settings tab.
9. click on OK to save the task.

### Setting up script execution with Local Group Policy Editor

To setup the script for execution at user log off do the following:

1. Go to Start Menu -> Run (or press Win Key + R).
2. Type `gpedit.msc` and hit enter to open Local Group Policy Editor.
3. Go to User configuration -> Windows Settings -> Scripts (Logon/Logoff).
4. Click on Logoff on the right and select PowerShell Scripts tab in the dialog.
5. Click on Add... button, then select the script.

To setup the script for execution at system shutdown do the following:

1. Go to Start Menu -> Run (or press Win Key + R).
2. Type `gpedit.msc` and hit enter to open Local Group Policy Editor.
3. Go to Computer configuration -> Windows Settings -> Scripts (Startup/Shutdown).
4. Click on Shutdown on the right and select PowerShell Scripts tab in the dialog.
5. Click on Add... button, then select the script.

## Requirements

The script requires:

* Windows 7 Service Pack 1 or newer;
* PowerShell 3.0 ([Windows Management Framework 3.0](https://www.microsoft.com/en-us/download/details.aspx?id=34595)) or newer;
* [.Net Framework 4.5](https://www.microsoft.com/en-us/download/details.aspx?id=30653) or newer.

## Known issues

The script is still a work in progress and it is quite rough currently. It
should handle its errors and provide possibility for setup what is to be backed
up in the form of a hash table.
