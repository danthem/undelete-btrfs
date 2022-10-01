#!/usr/bin/env bash
#Author: Daniel Elf
#Tested w/ btrfs-progs v5.19.1
#Description: Somewhat interactive "undeleter" for BTRFS file systems.
#  This will not work for every file in every scenario
#  The best 'undeletion' you can do is to recover from backup :-)
#Syntax: ./undeletebtrfs.sh <dev> <dst>
#Example: ./undeletebtrfs.sh /dev/sda1 /mnt/undeleted
#NOTE: device must be unmounted
# var declarations
dev=$1
dst=$2
roots="/tmp/btrfsroots.tmp"
depth=0
tmp="/tmp/undeleter.tmp"
IFS=$'\n'
rectype="none"
# vars that can be used to change font color
white=$(tput setaf 7)
blue=$(tput setaf 6)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
normal=$(tput sgr0) # default color

# Functions
function titler() {
# Function to surround whatever is inputted with some nice lines
        input=$1
        let count=${#input}+4
        eval printf '=%.0s' "{1..$count}"
        printf "\n| ${yellow}%s${normal} |\n" "$input"
        eval printf '=%.0s' "{1..$count}"
        printf "\n"
}

function spinner(){
  # This function takes care of the spinner used for long-lasting tasks
    local pid=$!
    local delay=0.75
    local spinstr='|/-'\\
    while [ -d /proc/"$pid" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function syntaxcheck(){
  # Check syntax
  if [[ -z $dev || -z $dst ]]; then
    titler "Undelete-BTRFS | Syntax error"
    printf "${red}Error: ${yellow}Invalid syntax or missing required parameters\n"
    printf "${normal}Syntax: ./script.sh ${blue}<dev> <dst>${normal}\n"
    printf "${green}Example: ${normal}sudo ./undelete.sh ${blue}/dev/sda1 /mnt/${normal}\n\n"
    exit 1
  elif [[ $EUID -ne 0 ]]; then
        titler "Undelete-BTRFS | User privilege level error"
    printf "${red}Error:${yellow} This script must be run with sudo (or as root) as btrfs restore requires it.\n"
    printf "${normal}Syntax example: sudo ./undelete.sh ${blue}/dev/sda1 /mnt/${normal}\n"
    printf "\n${yellow}Exiting...\n${normal}"
    exit 1
  fi
}

function mountcheck(){
  mount=$(grep -cw "$dev" /etc/mtab)
  if [[ ! $mount == "0" ]]; then
    titler "Undelete-BTRFS | Mountcheck failed"
    printf "${red}Error: ${blue}%s${yellow} is mounted! \nThis script can only be run against umounted devices. Please try again\n\n" "$dev"
    printf "Exiting...\n${normal}"
    exit 1
  fi
}

function regexbuild(){
  # The regex required by btrfs restore is utterly awkward... So we have a function for building it :-)
  >$tmp
  titler "Undelete-BTRFS | Regex builder"
  printf "Welcome and good luck!\nMake sure you've read the README at ${blue}https://github.com/danthem/undelete-btrfs${normal} before continuing.\n"
  printf "\nCheat sheet:\n•Remember to NOT include the mountpoint where FS is normally mounted. Pretend that you're in 'root' of the filesystem itself.\n"
  printf "•Example of a ${blue}file${normal} path on a mounted filesystem: ${white}/data/documents/daniel.txt${normal}\n"
  printf " -> How to write it: ${white}/documents/daniel.txt${normal}\n"
  printf "•Example of a ${blue}directory${normal} path on a mounted filesystem: ${white}/data/pictures/important/${normal}\n"
  printf " -> How to write it: ${white}/pictures/important/${normal}\n"
  printf "•Maybe you want recover for instance all ${blue}files with extension${normal} .jpeg in a directory?\n"
  printf " -> How to write it: ${white}/pictures/.*.jpeg${normal}\n\n"
  read -er -p "Enter the path to a file or folder, following the rules above: " filepath
  while [[ -z "$filepath" ]]; do
    printf "\n${red}Err: No input given, try again.\n${normal}"
    read -r -p "Enter the path to a file or folder, following the rules above: " filepath
  done
  # Pick out the dir and filename
  dirname=$(echo "$filepath" | awk -F"/" '{ print $(NF-1) }')
  filename=$(echo "$filepath" | awk -F"/" '{ print $NF }')
  # Check is first character is a /, if so ignore it
  if [[ $filepath == /* ]]; then
    filepath=$(echo "$filepath"| cut -c2-)
  fi
  # Determine type of recovery.. are we doing full folder or single file?
  # Not used right now but maybe in a future version...
  if [[ $filepath == */ ]]; then
    rectype="folder"
    recname="$dirname"
    filepath+=".*"
  else
    rectype="file"
    recname="$filename"
  fi
  # Read provided path to array

  readarray -d/ -t filepatharray < <(echo "$filepath")
  if  [[ ${#filepatharray[@]} -eq 1 ]];then 
    #no / found, user is looking for a file in root of FS itself.. Easy to build the regex
    regex="(|"${recname}")"
  else
    # Build the first set.. This is done to remove the / from the first seciotn
    regex="(|"${filepatharray[@]::1}""
    # Build the array one by one
    for i in "${filepatharray[@]:1}"; do
      regex+=$(printf "(|/%s" "$i")
    done
    # Finally add enough ")" at the end
    for i in "${filepatharray[@]}"; do
      regex+=")"
      #regex="$(echo $regex|tr -d "\n")"
    done
  fi
  #printf "\nRegex:\n${blue}^/%s$ ${normal}\n\n" "$regex"
  printf "\n${green}Great!${normal} First thing we will do is a dry-run, this will not actually recover any files, just check if we can find any files matching the regex.\n"
  sleep 5
  dryrun
  checkresult
}

function dryrun(){
  # This is where we do the dryrun of BTRFS, this is used to quickly check if we can find the file using the provided regexbuild
  # much faster than doing an actual restore.
  clear
  titler "Undelete-BTRFS | Dry-run | Depth-level: ${depth}"
  printf "Performing a dry-run recovery with the provided path.\n${yellow}This is not recovering any files, just checking if files can be found${normal}\n"
  sleep 2
  if [[ $depth -eq 0 ]]; then
    sudo btrfs restore -Div --path-regex '^/'${regex}'$' $dev /  2> /dev/null | grep -E "Restoring.*$recname" | cut -d" " -f 2- &> $tmp
    # We have 3 levels: 0, 1 and 2. 0 means a basic 'btrfs restore', 1 and 2 means that we first get the roots and then loop them
  elif [[ $depth -eq 1 ]]; then
    while read -r i || [[ -n "$i" ]]; do
      btrfs restore -t "$i" -Div --path-regex '^/'${regex}'$' "$dev" / 2> /dev/null | grep -E "Restoring.*$recname" | cut -d" " -f 2- &>> $tmp
    done < "$roots"
    # Level 2 is the 'deepest' level, here we add the -a flag to the btrfs-find-roots, this should give us way more roots to work with
  elif [[ $depth -eq 2 ]]; then
    while read -r i || [[ -n "$i" ]]; do
      btrfs restore -t "$i" -Div --path-regex '^/'${regex}'$' "$dev" / 2> /dev/null| grep -E "Restoring.*$recname" | cut -d" " -f 2- &>> $tmp
    done < "$roots"
  fi
  }

function checkresult(){
  clear
  titler "Undelete-BTRFS | Dry-run results | Depth-level: ${depth}"
  printf "Path entered: ${blue}%s${normal} \nRegex generated: ${blue}'^/%s\$'${normal} \nDepth-level: ${blue}%s${normal}\n\n" "$filepath" "$regex" "$depth"
  if [[ ! -s $tmp && $depth -eq 0 ]]; then
    # we didn't find any data on first attempt (as $tmp is empty)
    depth=1
    generateroots
    dryrun
    checkresult
  elif [[ ! -s $tmp && $depth -eq 1 ]]; then
    # didn't find any on the second attempt either
    depth=2
    generateroots
    dryrun
    checkresult
  elif [[ -s $tmp ]]; then
    # if $tmp is not empty, it means we found some data!
      printf "${green}Data found!${normal} here are the file(s) found: \n========\n"
      sort -u $tmp
      printf "========\n\nChoose one of the following: \n${blue}1${normal}) Recover the data \n${blue}2${normal}) Look one level deeper \n${blue}3${normal}) Try another path \n${blue}4${normal}) Exit\n"
      while true; do
        read -r -p "Enter choice: " input
        case $input in
          [1])
            recover
            ;;
          [2])
            if [[ $depth -eq 0 || $depth -eq 1 ]]; then
              printf "\nTrying one level deeper...\n\n"
              depth=$(($depth + 1))
              generateroots
              dryrun
              checkresult
            elif [[ $depth -eq 2 ]]; then
              printf "You're already on the deepest level... Can't go deeper! \n\n"
            fi
            ;;
          [3])
            clear
            printf "${yellow}Returning to path selection...${normal}\n\n"
            depth=0
            regexbuild
            ;;
          [4])
            exit 0
            ;;
          *)
          printf "\nInvalid input.\n"
        esac
      done
  else
    printf "${red}No data found :(${normal}\nUnable to find any data with the provided path at any depth level, please verify the entered path and try again\n"
    printf "Keep in mind that directory paths must end with a '/' \nFor more rules/examples see ${blue}https://github.com/danthem/undelete-btrfs${normal}\n\n"
    read -s -p "Press Enter to return to start..."
    clear
    depth=0
    printf "${yellow}Returning to path selection...${normal}\n\n"
    regexbuild
  fi
}

function generateroots(){
  clear
  titler "Undelete-BTRFS | Generating roots | Depth-level ${depth}"
  if [[ $depth -eq 1 || $depth -eq 0 ]]; then
    printf "Generating roots, please note that this may take a while to finish... "
    btrfs-find-root "$dev" &> "$tmp"
    grep -a Well "$tmp" | sed -r -e 's/Well block ([0-9]+).*/\1/' | sort -rn > "$roots"
    printf "${green}Done${normal}!\n"
    rootcount=$(wc -l "$roots" | awk '{print $1}')
    > "$tmp"
    if [[ ! -s "$roots" ]]; then
      printf "\n${yellow}Note:${normal} No (additional) roots found with btrfs-find-roots \nAttempting with -a flag (depth level 2)...\n"
      depth=2
      sleep 2
      generateroots
    fi
  elif [[ $depth -eq 2 ]]; then
    printf "Looking even deeper for roots, this can take quite a while... "
    btrfs-find-root -a "$dev" &> "$tmp"
    grep -a Well "$tmp" | sed -r -e 's/Well block ([0-9]+).*/\1/' | sort -rn > "$roots"
    printf "${green}Done${normal}!\n"
    rootcount=$(wc -l $roots | awk '{print $1}')
    > "$tmp"
  fi
}

function recover(){
  # Attempt recovery of files
  clear
  titler "Undelete-BTRFS | Recovering files | Depth-level: ${depth}"
  if [[ $depth = "0" ]]; then
    sudo btrfs restore -iv --path-regex '^/'${regex}'$' "$dev" "$dst"  &> /dev/null
    recoveredfiles=$(find $dst ! -empty -type f | wc -l)
    # Find and delete empty recovered files, no point in keeping them around.
    find $dst -empty -type f -delete
  elif [[ $depth == "1" ]]; then
    printf "Attempting recovery at depth level ${blue}%s${normal}, note that this may take a while..." "$depth"
    while read -r i || [[ -n "$i" ]]; do
      btrfs restore -t "$i" -iv --path-regex '^/'${regex}'$' "$dev" "$dst" &> /dev/null
    done < "$roots" &
    spinner
    printf "${green}Done${normal}! \n"
    # Find and delete empty files in $dst
    # so that we don't skip recovering a file on next iteration just because an empty version of the same file was recovered
    recoveredfiles=$(find $dst ! -empty -type f | wc -l)
  elif [[ $depth == "2" ]]; then
    printf "\n${yellow}NOTE:${normal} You are about to start recovery at the deepest level. \nThis may take a long time and it's possible that console will get flooded with '(core dumped)'-messages.\nThis is normal and can be ignored.\n\n"
    read -r -n1 -p "Press any key to continue..."
    printf "Attempting recovery at depth level ${blue}%s${normal}, note that this may take a while..." "$depth"
    while read -r i || [[ -n "$i" ]]; do
      btrfs restore -t "$i" -iv --path-regex '^/'${regex}'$' "$dev" "$dst" &> /dev/null
      find $dst -empty -type f -delete
    done < "$roots" &
    spinner
    printf "${green}Done${normal}! \n"
    recoveredfiles=$(find $dst ! -empty -type f | wc -l)
  fi
  checkrecoverresults
}

function checkrecoverresults(){
  clear
  titler "Undelete-BTRFS | Recovery completed | Depth-level: ${depth}"
  if [[ $depth = "0" || $depth = "1" ]]; then
    printf "Recovery completed at depth level ${blue}%s${normal}! \n ==> ${blue}%s${normal} non-empty files found in %s.\n\n" "$depth" "$recoveredfiles" "$dst"
    printf "Here's a small sample of '${white}find %s -type f${normal}' output:\n========\n" "$dst"
    find "$dst" -type f | head -n20
    printf "========\\n(Showing max 20 files)\n\n"
    printf "Are you happy with the results?\n${blue}1${normal}) Yes, exit script. \n${blue}2${normal}) No, try a deeper level restore. \n${blue}3${normal}) No, I want to try a different path.\n\n"
    while true; do
      read -r -p "Enter choice: " input
      case $input in
        [1])
          printf "\nExiting...\n\n"
          exit 0
          ;;
        [2])
          printf "Trying one level deeper..\n\n"
          depth=$(($depth + 1))
          generateroots
          recover
          ;;
        [3])
          printf "\nReturning to path selection....\n\n"
          depth=0
          regexbuild
          ;;
        *)
        printf "\nInvalid input.\n"
      esac
    done
  elif [[ $depth = "2" ]]; then
    printf "Deepest level recovery completed! \n ==> ${blue}%s${normal} non-empty files found in %s.\n\n" "$recoveredfiles" "$dst"
    printf "Here's a small sample of '${white}find %s -type f${normal}' output:\n========\n" "$dst"
    find "$dst" -type f | head -n20
    printf "========\n\n"
    printf "Are you happy with the results?\n${blue}1${normal}) Yes, exit script. \n${blue}2${normal}) No, I want to try a different path.\n\n"
    while true; do
      read -r -p "Enter choice: " input
      case $input in
        [1])
          printf "\nExiting...\n\n"
          rm "$roots" "$tmp"
          exit 0
          ;;
        [2])
          printf "\nReturning to path selection....\n\n"
          depth=0
          regexbuild
          ;;
        *)
        printf "\nInvalid input.\n"
      esac
    done
  fi
}

#Exec start
syntaxcheck
mountcheck
clear
>$tmp
>$roots
regexbuild
