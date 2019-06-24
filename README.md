# undelete-btrfs
A tool to automate the creation of --path-restore regex for BTRFS as well as actually perform the undeletion for you.
Note: The longer a file has existed, the more likely it is to be recovered. This means that the script may not work well on "test"-setups where you just create a file and then instantly try to recover it, but it should work decently on a 'real' system.

 You may also end up recovering an older version of the file. Script will try to recover the most recent version but there's no guarantee the most recent recoverable version is actually the most recent version of the file.

Tested with: btrfs-progs 4.15

## Syntax
Syntax: ```./script.sh <dev> <dst>```

Example: ```sudo ./undelete.sh /dev/sda1 /mnt/```

Note: <dev> cannot be mounted while you run this script.

## I just deleted an important file - what do I do?
*Stop what you're doing

*Umount the FS where the file was located

*Look for up-to-date backups and restore them if possible

*If no backups, attempt to run this script.


## How to use it
Upon launch of the script it will ask you to enter the path to the file you're looking to recover. Simply enter the path to the file or the directory you're looking for like but exclude the mount-point for the volume... Here's what it should look like:

### Recovery of a file:
Actual path to file: /data/Documents/bills/electric.pdf

How to write it in script: /Documents/bulls/electric.pdf

### Recovery of a folder:
Actual path to folder: /data/Pictures/2017/Iceland/

How to write it in the script: /Pictures/2017/Iceland/

Note that for directory recoveries the path entered must end with a slash ("/").

## What is actually going on?
Well, there are some comments in the code... Have a read through that and see if you can make sense of it. But to keep it simple the script will attempt three different 'depths' of recovery... It will go through them one by one, if data is found it prompt you if the data found is what you're looking for or if you want to look deeper.

## Depth?
As you run the script you will see different "depth" levels. There are basically three levels of depth; 0, 1 and 2.

#### Depth 0:
A simple btrfs-restore with the regex built from the path
#### Depth 1: 
Find alternative roots using btrfs-find-roots, loop through them looking for data based on the provided path.
#### Depth 2: 
Same as above but the btrfs-find-roots is run with the -a flag which generates a lot more roots. This can be very slow to go through. 

A note about depth 2 as well is that it seems like btrfs restore does segfault on some roots provided. So while running this your terminal may be flooded with (core-dumped)-messages. This is expected (well.. kind of).  

## Current limitations 
*Possibly issues with special characters in file or folder name

*Does not play well in systems where readarray does not take the -d flag

## Important note
There is no native undeletion feature of BTRFS. This  script utilizes btrfs restore as well as btrfs-find-root to attempt recovery of deleted files on a given path. There are absolutely no guarantees it will work to recover the file. The best undeletion tool is to restore from backup. The longer a file has existed on your system, the more likely a successful recovery will be.

