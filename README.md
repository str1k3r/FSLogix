# FSLogix
FSLogix Scripts

UPM to Profile Container

Local Profile to Profile Container

NOTE: This only works between like profile versions.  eg. You can’t migrate your 2008R2 profiles to Server 2016 and expect it to work.

This requires using frx.exe, which means that FSLogix needs to be installed on the server that contains the profiles. The script will create the folders in the USERNAME_SID format, and set all proper permissions.

Use this script. Edit it. Run it (as administrator) from the Citrix server. It will pop up this screen to select what profiles to migrate.


Profile Disk to Profile Container
