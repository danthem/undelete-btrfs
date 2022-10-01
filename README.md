# undelete-btrfs
A tool for automating the generation of path regex for BTRFS restore as well as attempt the restore for you in 3 levels.
The longer a file has existed prior to being deleted, the more likely it is to be recovered. This means that the script may not always work well in "test"-environments where you just create a file and then instantly try to recover it, but it should work decently on a 'real' system.

You may also end up recovering an older version of the file. The script will try to recover the most recent version but there's no guarantee the most recent recoverable version is the most recent version of the file.

Script has been tested and confirmed working with btrfs-progs version: `v5.19.1` (script should also work on older versions)

## Syntax
Syntax: ```./undelete.sh <source dev> <recovery destination>```

Example: ```sudo ./undelete.sh /dev/sda1 /mnt/```

Note: \<source dev\> cannot be mounted while you run this script.

## I just deleted an important file - what do I do?
* Stop what you're doing
* Umount the FS where the file was located
* Look for up-to-date backups and restore them if possible
* If no backups, attempt to run this script
    * The filesystem needs to be unmounted during this activity, if it's the root path of your OS you'll need to boot from a live USB


## How to use it
When launching the script you will be asked to provide the path to the file/directory you're looking to recover. When entering the path you need to exclude the normal mountpoint for the BTRFS volume, you need to imagine that you're writing relative path from the root of the BTRFS volume itself. Here are some examples of what it should look like:

### **Recovery of a file**:
Actual path to file: **/data**/Documents/bills/electric.pdf

How to write it in script: `/Documents/bulls/electric.pdf`

### **Recovery of a directory**:
Actual path to directory: **/data**/Pictures/2017/Iceland/

How to write it in the script: `/Pictures/2017/Iceland/`


> ⚠ Pay attention to the fact that for directory recoveries the path entered **must** end with a slash ("/"). This tells the script that we're dealing with a directory instead of a file.

### **Recovery of certain extensions**:
On whole volume, regardless of path: `.*/.*.pdf`

Within a certain directory: `/documents/finance/.*.pdf`


## What is actually going on?
Well, there are comments in the code, have a read through that and see if you can make sense of it. But to keep it short and simple: The script automatically generates the somewhat awkward regex syntax required by `btfs restore` and then attempts three different 'depths' of recovery... It will go through them one by one, if data is found at any level the script will prompt you if the data found is what you're looking for or if you want to look deeper. 

## Depth?
As you run the script you will see different "depth" levels. The depth level determines how deep we dig for the data, the deeper we go the slower the recovery but also the chance for recovery increases. There are three levels of depth in the undelete-btrfs script: 0, 1 and 2.

#### Depth 0:
A simple `btrfs restore` with the regex built from the path provided.
#### Depth 1: 
Find alternative roots using `btrfs-find-roots`, script loops through every root one by one looking for data matching the generated regex frm path.
#### Depth 2: 
Same as above but the `btrfs-find-roots` is run with the -a flag which generates a lot more roots. This will is the slowest recovery level, it may take a long time to complete. 

Regarding depth level 2: It's somewhat common that `btrfs restore` segfaults on roots found here, this will flood your terminal with (core-dumped)-messages but the recovery should continue as expected. Remember that depth 2 is the deepest we go and this may take a long time to complete.

## Current/known limitations 
* If you try to recover a directory make sure to end the path with a slash (/), otherwise you might get a match on dryrun but no files restored during recovery.
* Path and file names are CASE SENSITIVE
    * You can change this behavior by modifying script and adding -c to any `btrfs restore`-command

## Important note
There is no native undelete feature in BTRFS. This script utilizes `btrfs restore` as well as `btrfs-find-root` to attempt recovery of deleted files on a given path. There are absolutely no guarantees it will work to recover the file. The best undeletion tool is to restore from backup. The longer a file has existed on your system, the more likely a successful recovery will be.

