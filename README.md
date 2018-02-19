# undelete-btrfs
A tool to automate the creation of --path-restore regex for BTRFS as well as actually perform the undeletion for you.

Tested with: btrfs-progs 4.15

## Syntax
Syntax: ```./script.sh <dev> <dst>```
Example: ```./undelete.sh /dev/sda1 /mnt/```


## How to use it
Upon launch of the script it will ask you to enter the path to the file you're looking to recover. Simply enter the path to the file or the directory you're looking for like but exclude the mount-point for the volume... Here's what it should look like:

### Recovery of a file:
Actual path to file: /data/Documents/bills/electric.pdf
How to write it in script: /Documents/bulls/electric.pdf

### Recovery of a folder:
Actual path to folder: /data/Pictures/2017/Iceland/
How to write it in the script: /Pictures/2017/Iceland/

Note that for directory recoveries the path entered must end with a slash ("/").


## Current limitations: 
*Possibly issues with special characters in file or folder name
*Does not play well in systems where readarray does not take the -d flag
