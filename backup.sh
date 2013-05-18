#!/bin/bash

BR_VERSION="System Tar & Restore 3.1"

color_variables() {
  BR_NORM='\e[00m'
  BR_RED='\e[00;31m'
  BR_GREEN='\e[00;32m'
  BR_YELLOW='\e[00;33m'
  BR_BLUE='\e[00;34m'
  BR_MAGENTA='\e[00;35m'
  BR_CYAN='\e[00;36m'
}

clear

show_summary() {
  echo "DESTINATION: $BRFOLDER"
  echo "COMPRESSION: $BRcompression"

  if [ "$BRhome" = "Yes" ]; then
    echo "HOME DIR: Include"
  elif [ "$BRhome" = "No" ] && [ "$BRhidden" = "Yes" ]; then
    echo "HOME DIR: Only hidden files and folders"
  elif [ "$BRhome" = "No" ] && [ "$BRhidden" = "No" ]; then
    echo "HOME DIR: Exclude"
  fi
  if [ $BRtar = "y" ]; then
    echo "EXTRA OPTIONS: --acls --selinux --xattrs"
  fi
  if [ -n "$BR_USER_OPTS" ]; then
    echo "USER OPTIONS: $BR_USER_OPTS"
  fi
}

set_tar_options() {
  BR_TAROPTS="--sparse $BR_USER_OPTS --exclude=/run/* --exclude=/dev/* --exclude=/proc/* --exclude=lost+found --exclude=/sys/* --exclude=/media/* --exclude=/tmp/* --exclude=/mnt/* --exclude=.gvfs"

  if [ ${BRhome} = "No" ] &&  [ ${BRhidden} = "No" ] ; then
    BR_TAROPTS="${BR_TAROPTS} --exclude=/home/*"
  elif [ ${BRhome} = "No" ] &&  [ ${BRhidden} = "Yes" ] ; then
    find /home/*/  -maxdepth 1 -iname ".*" -prune -o -print   > /tmp/list
    BR_TAROPTS="${BR_TAROPTS} --exclude-from=/tmp/list"
  fi

  if [ ${BRtar} = "y" ]; then
    BR_TAROPTS="${BR_TAROPTS} --acls --selinux --xattrs"
  fi
}

run_calc() {
  tar cvf /dev/null ${BR_TAROPTS} --exclude="$BRFOLDER" / 2> /dev/null | tee "$BRFOLDER"/log | while read ln; do a=$(( a + 1 )) && echo -en "\rCalculating: $a"; done
}

run_tar() {
  if [ ${BRcompression} = "GZIP" ]; then
     tar cvpzf  "$BRFile".tar.gz  ${BR_TAROPTS} --exclude="$BRFOLDER" /
     if [ $? -gt 0 ]; then
       touch /tmp/b_error
     fi
  elif [ ${BRcompression} = "XZ" ]; then
     tar cvpJf  "$BRFile".tar.xz  ${BR_TAROPTS} --exclude="$BRFOLDER" /
     if [ $? -gt 0 ]; then
       touch /tmp/b_error
     fi
  fi
}

BRargs=`getopt -o "i:d:c:u:hnN" -l "interface:,directory:,compression:,user-options:,exclude-home,no-hidden,no-color,help" -n "$1" -- "$@"`

if [ $? -ne 0 ]; then
  echo "See $0 --help"
  exit
fi

eval set -- "$BRargs";

while true; do
  case "$1" in
    -i|--interface)
      BRinterface=$2
      shift 2
    ;;
    -u|--user-options)
      BRuseroptions="Yes"
      BR_USER_OPTS=$2
      shift 2
    ;;
    -d|--directory)
      BRFOLDER=$2
      shift 2
    ;;
    -c|--compression)
      BRcompression=$2
      shift 2
    ;;
    -h|--exclude-home)
      BRhome="No"
      shift
    ;;
    -n|--no-hidden)
      BRhidden="No"
      shift
    ;;
    -N|--no-color)
      BRnocolor="y"
      shift
    ;;
    --help)
      echo "
-i, --interface         interface to use (CLI Dialog)
-N, --no-color          disable colors
-d, --directory		path for backup folder
-h, --exclude-home	exclude /home
-n  --no-hidden         dont keep home's hidden files and folders
-c, --compression       compression type (GZIP XZ)
-u, --user-options      additional tar options (See tar --help)

--help	print this page
"
      exit
      shift
    ;;
    --)
      shift
      break
    ;;
  esac
done

if [ -z "$BRnocolor" ]; then
  color_variables
fi

if [ $(id -u) -gt 0 ]; then
  echo -e "${BR_RED}Script must run as root${BR_NORM}"
  exit
fi

if [ -f /etc/yum.conf ]; then
  BRtar="y"
else
  BRtar="n"
fi

if [ ! -d "$BRFOLDER" ] && [ -n "$BRFOLDER" ]; then
  echo -e "${BR_RED}Directory does not exist:${BR_NORM} $BRFOLDER"
  BRSTOP=y
fi

if  [ -n "$BRcompression" ] && [ ! "$BRcompression" =  "GZIP" ] && [ ! "$BRcompression" =  "XZ" ]; then
  echo -e "${BR_RED}Wrong compression type:${BR_NORM} $BRcompression"
  echo -e "${BR_CYAN}Supported compressors: GZIP XZ${BR_NORM}"
  BRSTOP=y
fi

if  [ -n "$BRinterface" ] && [ ! "$BRinterface" =  "CLI" ] && [ ! "$BRinterface" =  "Dialog" ]; then
  echo -e "${BR_RED}Wrong interface name:${BR_NORM} $BRinterface\n${BR_CYAN}Available options: CLI Dialog${BR_NORM}"
  BRSTOP=y
fi

if [ -n "$BRSTOP" ]; then
  exit
fi

if [ -n "$BRFOLDER" ]; then
  if [ -z "$BRhome" ]; then
    BRhome="Yes"
  fi
  if [ -z "$BRhidden" ]; then
    BRhidden="Yes"
  fi
  if [ -z "$BRuseroptions" ]; then
    BRuseroptions="No"
  fi
fi

PS3="Choice: "
interfaces=(CLI Dialog)

while [ -z "$BRinterface" ]; do
  echo -e "\n${BR_CYAN}Select interface or enter Q to quit${BR_NORM}"
  select c in ${interfaces[@]}; do
    if [ $REPLY = "q" ] || [ $REPLY = "Q" ]; then
      echo -e "${BR_YELLOW}Aborted by User${BR_NORM}"
      exit
    elif [[ $REPLY = [0-9]* ]] && [ $REPLY -gt 0 ] && [ $REPLY -le ${#interfaces[@]} ]; then
      BRinterface=$c
      break
    else
      echo -e "${BR_RED}Please select a valid option from the list or enter Q to quit${BR_NORM}"
    fi
  done
done

if [ $BRinterface = "CLI" ]; then
  clear
  echo "$BR_VERSION"
  echo " "
  DEFAULTIFS=$IFS
  IFS=$'\n'

  if [ -z "$BRFOLDER" ]; then
    echo "This script will make a tar backup image of your entire system."
    echo -e "\n==>Make sure you have enough free space."
    echo -e "\n==>Also make sure you have GRUB or SYSLINUX packages installed."
    echo -e "\n${BR_YELLOW}GRUB Packages:${BR_NORM}"
    echo "Arch: grub-bios"
    echo "Debian: grub-pc"
    echo "Fedora: grub2"
    echo -e "\n${BR_YELLOW}SYSLINUX Packages:${BR_NORM}"
    echo "Arch: syslinux"
    echo "Debian: syslinux extlinux"
    echo "Fedora: syslinux syslinux-extlinux"
    echo -e "\n${BR_CYAN}Press ENTER to continue.${BR_NORM}"
    read -s a
    clear
  fi

  while [ -z "$BRFOLDER" ]; do
    echo -e "\n${BR_CYAN}The default folder for creating the backup image is / (root).\nSave in the default folder?${BR_NORM}"
    read -p "(Y/n): " an

    if [ -n "$an" ]; then
      def=$an
    else
      def="y"
    fi

    if [ $def = "y" ] || [ $def = "Y" ]; then
      BRFOLDER="/"
    elif [ $def = "n" ] || [ $def = "N" ]; then
      while [  -z "$BRFOLDER" ] || [ ! -d "$BRFOLDER" ]; do
        echo -e "\n${BR_CYAN}Insert the folder path where the backup will be created${BR_NORM}"
        read -p "Path: " BRFOLDER
        if [ ! -d "$BRFOLDER" ]; then
          echo -e "${BR_RED}Directory does not exist.${BR_NORM}"
        fi
      done
    else
      echo -e "${BR_RED}Please enter a valid option${BR_NORM}"
    fi
  done

  while [ -z "$BRhome" ] ; do
    echo -e "\n${BR_CYAN}Include /home directory?${BR_NORM}"
    read -p "(Y/n):" an

    if [ -n "$an" ]; then
      def=$an
    else
      def="y"
    fi

    if [ $def = "y" ] || [ $def = "Y" ]; then
      BRhome="Yes"
    elif [ $def = "n" ] || [ $def = "N" ]; then
      BRhome="No"
    else
      echo -e "${BR_RED}Please enter a valid option${BR_NORM}"
    fi
  done

  if [ $BRhome = "No" ]; then
    while [ -z "$BRhidden" ] ; do
      echo -e "\n${BR_CYAN}Keep hidden files and folders inside /home?${BR_NORM}"
      read -p "(Y/n):" an

      if [ -n "$an" ]; then
        def=$an
      else
        def="y"
      fi

      if [ $def = "y" ] || [ $def = "Y" ]; then
        BRhidden="Yes"
      elif [ $def = "n" ] || [ $def = "N" ]; then
        BRhidden="No"
      else
        echo -e "${BR_RED}Please enter a valid option${BR_NORM}"
      fi
    done
  fi

  while [ -z "$BRuseroptions" ]; do
    echo -e "\n${BR_CYAN}Enter additional tar options?${BR_NORM}"
    read -p "(y/N):" an

    if [ -n "$an" ]; then
      def=$an
    else
      def="n"
    fi

    if [ $def = "y" ] || [ $def = "Y" ]; then
      BRuseroptions="Yes"
      read -p "Enter options (See tar --help):" BR_USER_OPTS
      echo "Options: $BR_USER_OPTS"
    elif [ $def = "n" ] || [ $def = "N" ]; then
      BRuseroptions="No"
    else
      echo -e "${BR_RED}Please enter a valid option${BR_NORM}"
    fi
  done

  while [ -z "$BRcompression" ]; do
    echo -e "\n${BR_CYAN}Select the type of compression:${BR_NORM}"
    select c in "GZIP (Fast, big file)" "XZ   (Slow, smaller file)"; do
      if [[ $REPLY = [0-9]* ]] && [ $REPLY -eq 1 ]; then
        BRcompression="GZIP"
        break
      elif [[ $REPLY = [0-9]* ]] && [ $REPLY -eq 2 ]; then
        BRcompression="XZ"
        break
      else
        echo -e "${BR_RED}Please enter a valid option from the list${BR_NORM}"
      fi
    done
  done

  IFS=$DEFAULTIFS

  echo -e "\n${BR_GREEN}SUMMARY${BR_NORM}"
  show_summary

  while [ -z "$BRcontinue" ]; do
    echo -e "\n${BR_CYAN}Continue?${BR_NORM}"
    read -p "(Y/n):" an

    if [ -n "$an" ]; then
      def=$an
    else
      def="y"
    fi

    if [ $def = "y" ] || [ $def = "Y" ]; then
      BRcontinue="y"
    elif [ $def = "n" ] || [ $def = "N" ]; then
      BRcontinue="n"
      echo -e "${BR_YELLOW}Aborted by User${BR_NORM}"
      exit
    else
      echo -e "${BR_RED}Please enter a valid option${BR_NORM}"
    fi
  done

  if [  "x$BRcontinue" = "xy" ]; then
    BRFOLDER_IN=(`echo ${BRFOLDER}/Backup-$(date +%d-%m-%Y) | sed 's://*:/:g'`)
    BRFOLDER="${BRFOLDER_IN[@]}"

    echo "==>Preparing..."
    mkdir -p "$BRFOLDER" 2>> "$BRFOLDER"/backup.log
    echo "--------------$(date +%d-%m-%Y-%T)--------------" >> "$BRFOLDER"/backup.log
    sleep 1
    BRFile="$BRFOLDER"/Backup-$(hostname)-$(date +%d-%m-%Y-%T)
    set_tar_options
    run_calc
    total=$(cat "$BRFOLDER"/log | wc -l)
    sleep 1
    echo " "
    run_tar 2>>"$BRFOLDER"/backup.log | while read ln; do b=$(( b + 1 )) && echo -en "\rCompressing: $b of $total $(($b*100/$total))%"; done
    echo " "
    echo "==>Setting permissions"
    chmod ugo+rw -R "$BRFOLDER" 2>> "$BRFOLDER"/backup.log
    rm "$BRFOLDER"/log 2>> "$BRFOLDER"/backup.log
    if [ -f /tmp/b_error ]; then
      echo -e "${BR_RED}An error occurred. Check "$BRFOLDER"/backup.log for details. Press ENTER to exit.${BR_NORM}"
    else
      echo -e "${BR_CYAN}Completed. Backup archive and log saved in $BRFOLDER. Press ENTER to exit.${BR_NORM}"
    fi
  fi

  read -s a

elif [ $BRinterface = "Dialog" ]; then
  if [ -z $(which dialog 2> /dev/null) ];then
    echo -e "${BR_RED}Package dialog is not installed\n${BR_CYAN}Install the package and re-run the script${BR_NORM}"
    exit
  fi

  if [ -z "$BRFOLDER" ]; then
    dialog --no-ok --title "$BR_VERSION" --msgbox  "This script will make a tar backup image of your entire system.

==>Make sure you have enough free space.

==>Make sure you have GRUB or SYSLINUX packages installed.

GRUB Packages:
-->Arch: grub-bios
-->Debian: grub-pc
-->Fedora: grub2

SYSLINUX Packages:
-->Arch: syslinux
-->Debian: syslinux extlinux
-->Fedora: syslinux syslinux-extlinux

Press OK to continue." 22 70
  fi

  while [ -z "$BRFOLDER" ]; do
    dialog  --yesno "The default folder for creating the backup image is / (root).\nSave in the default folder?" 8 65
    if [ $? = "0" ]; then
      BRFOLDER="/"
    else
      while [  -z "$BRFOLDER" ] || [ ! -d "$BRFOLDER" ]; do
        exec 3>&1
        BRFOLDER=$(dialog  --no-cancel --inputbox "Insert the folder path where the backup will be created" 8 50 2>&1 1>&3)
        if [ ! -d "$BRFOLDER" ]; then
          echo "Directory does not exist" | dialog --title "Error" --progressbox 3 28
          sleep 2
        fi
      done
    fi
  done

  while [ -z "$BRhome" ]; do
    dialog  --yesno "Include /home directory?" 6 35
    if [ $? = "0" ]; then
      BRhome="Yes"
    else
      BRhome="No"
    fi
  done

  if [ $BRhome = "No" ]; then
    while [ -z "$BRhidden" ] ; do
      dialog   --yesno "Keep hidden files and folders inside /home?" 6 50
      if [ $? = "0" ]; then
        BRhidden="Yes"
      else
        BRhidden="No"
      fi
    done
  fi

  exec 3>&1

  while [ -z "$BRuseroptions" ]; do
    dialog   --yesno "Specify additional tar options?" 6 35
    if [ $? = "0" ]; then
      BRuseroptions="Yes"
      BR_USER_OPTS=$(dialog  --no-cancel --inputbox "Enter additional tar options: (See tar --help)" 8 70 2>&1 1>&3)
    else
      BRuseroptions="No"
    fi
  done

  while [ -z "$BRcompression" ]; do
    BRcompression=$(dialog --no-cancel  --menu "Select compression type:" 12 35 12  GZIP "Fast, big file" XZ "Slow, smaller file" 2>&1 1>&3)
  done

  dialog --title "Summary"  --yesno "`show_summary`

Press Yes to continue or No to abort." 0 0

  if [ $? = "1" ]; then
    exit
  fi

  BRFOLDER_IN=(`echo ${BRFOLDER}/Backup-$(date +%d-%m-%Y) | sed 's://*:/:g'`)
  BRFOLDER="${BRFOLDER_IN[@]}"

  mkdir -p "$BRFOLDER" 2>> "$BRFOLDER"/backup.log
  echo "--------------$(date +%d-%m-%Y-%T)--------------" >> "$BRFOLDER"/backup.log
  sleep 1

  BRFile="$BRFOLDER"/Backup-$(hostname)-$(date +%d-%m-%Y-%T)
  set_tar_options
  run_calc | dialog  --progressbox  3 40
  total=$(cat "$BRFOLDER"/log | wc -l)
  sleep 1
  run_tar 2>>"$BRFOLDER"/backup.log | while read ln; do b=$(( b + 1 )) && echo -en "\rCompressing: $b of $total $(($b*100/$total))%"; done | dialog  --progressbox  3 50

  chmod ugo+rw -R "$BRFOLDER" 2>> "$BRFOLDER"/backup.log
  rm "$BRFOLDER"/log 2>> "$BRFOLDER"/backup.log
  if [ -f /tmp/b_error ]; then
    dialog --title "Error" --msgbox  "An error occurred.\n\nCheck "$BRFOLDER"/backup.log for details." 8 80
  else
    dialog --title "Info" --msgbox  "Completed.\n\nBackup archive and log saved in $BRFOLDER." 8 80
  fi
fi

if [ -f /tmp/list ]; then
  rm  /tmp/list
fi

if [ -f /tmp/b_error ]; then
  rm /tmp/b_error
fi