#!/bin/bash
#
# For debug
# set -x
#

##############################################################################
# Script-Name : backup_lvm_snap.sh                                           #
# Description : Script to create and to backup the LVM Snapshot              #
#               On successful execution only a LOG file will be written.     #
#               On error while execution, a LOG file and a error message     #
#               will be send by e-mail.                                      #
#                                                                            #
# Created     : 02.08.2022                                                   #
# Last update : 30.06.2023                                                   #
# Version     : 0.1.5                                                        #
#                                                                            #
# Author      : Johann Hahn, <j.hahn@wassermann*****technik.de>              #
# DokuWiki    : https://docu.***.wassermanngruppe.de                         #
# Homepage    : https://wassermanngruppe.de                                  #
# GitHub      : https://github.com/johann8/tools                             #
# Download    : https://raw.githubusercontent.com/johann8/tools/master/ \    #
#               backup_lvm_snap.sh                                           #
#                                                                            #
#  +----------------------------------------------------------------------+  #
#  | This program is free software; you can redistribute it and/or modify |  #
#  | it under the terms of the GNU General Public License as published by |  #
#  | the Free Software Foundation; either version 2 of the License, or    |  #
#  | (at your option) any later version.                                  |  #
#  +----------------------------------------------------------------------+  #
#                                                                            #
# Copyright (c) 2022 by Johann Hahn.                                         #
#                                                                            #
##############################################################################

##############################################################################
# >>> Please edit following lines for personal settings and custom usages. ! #
##############################################################################

# CUSTOM - LV
VOLGROUP=opt                                                 # lvdisplay: name of the volume group
ORIGVOL=opt                                                  # lvdisplay: name of the logical volume to backup
SNAPVOL=opt_snap                                             # name of the snapshot to create
SNAPSIZE=5G                                                  # space to allocate for the snapshot in the volume group

# CUSTOM - script
SCRIPT_NAME="backupLVS.sh"                                   # LVS - logical volume snapshot
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.1.5"

# CUSTOM - vars
#BASENAME="${0##*/}"
SCRIPTDIR="${0%/*}"
BACKUPDIR="/mnt/NAS_BareOS/docker/$(hostname -s)/lvm-snapshot/$(date "+%Y-%m-%d")"  # where to put the backup
TIMESTAMP="$(date +%Y%m%d-%Hh%M)"
_DATUM="$(date '+%Y-%m-%d %Hh:%Ms')"
BACKUPNAME="${ORIGVOL}_${TIMESTAMP}.tgz"                           # name of the archive
TAR_EXCLUDE_VAR="--exclude-from=${SCRIPTDIR}/tar_exclude_var.txt"  # Files to be excluded from tar archive
MOUNTDIR="/mnt/lvm_snap"
SEARCHDIR="${BACKUPDIR%/*}"


# CUSTOM - logs
FILE_LAST_LOG='/tmp/'${SCRIPT_NAME}'.log'
FILE_MAIL='/tmp/'${SCRIPT_NAME}'.mail'

# CUSTOM - Send mail
MAIL_STATUS='Y'                                 # Send Status-Mail [Y|N]
PROG_SENDMAIL='/sbin/sendmail'
VAR_HOSTNAME=$(uname -n)
VAR_SENDER='root@'${VAR_HOSTNAME}
VAR_EMAILDATE=$(date '+%a, %d %b %Y %H:%M:%S (%Z)')

# CUSTOM - Mail-Recipient.
MAIL_RECIPIENT='you@example.com'

# CUSTOM - Days number of stored backups
BACKUP_DAYS=6

#FILE_LAST_LOG="/var/log/container_backup.log"
#BACKUP_DAYS=6                                                      # Number of backup files

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

#
### === Functions ===
#

# Function print script basename
print_basename() {
   echo -e "${BASENAME}: $1"
}

# Function: send mail
function sendmail() {
     case "$1" in
     'STATUS')
               MAIL_SUBJECT='Status execution '${SCRIPT_NAME}' script.'
              ;;
            *)
               MAIL_SUBJECT='ERROR while execution '${SCRIPT_NAME}' script !!!'
               ;;
     esac

cat <<EOF >$FILE_MAIL
Subject: $MAIL_SUBJECT
Date: $VAR_EMAILDATE
From: $VAR_SENDER
To: $MAIL_RECIPIENT
EOF

# sed: Remove color and move sequences
echo -e "\n" >> $FILE_MAIL
cat $FILE_LAST_LOG  >> $FILE_MAIL
${PROG_SENDMAIL} -f ${VAR_SENDER} -t ${MAIL_RECIPIENT} < ${FILE_MAIL}
rm -f ${FILE_MAIL}
}


#
### ============= Main script ============
#

echo -e "\n" 2>&1 | tee ${FILE_LAST_LOG}
print_basename "Script version is: \"${SCRIPT_VERSION}\"" 2>&1 | tee ${FILE_LAST_LOG}
print_basename "Datum: $(date "+%Y-%m-%d")" 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename "============================" 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename " Run backup of LV snapshot" 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename "============================" 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename "Started on \"$(hostname -f)\" at \"${_DATUM}\"" 2>&1 | tee -a ${FILE_LAST_LOG}
echo " " 2>&1 | tee -a ${FILE_LAST_LOG}


# only run as root
if [ "$(id -u)" != '0' ]; then
   print_basename "This script has to be run as root" 2>&1 | tee -a ${FILE_LAST_LOG}
   exit 1
fi

# check that the snapshot does not already exist
if [ -e "/dev/${VOLGROUP}/${SNAPVOL}" ]; then
   print_basename "LV snapshot already exists, please destroy it by hand first" 2>&1 | tee -a  ${FILE_LAST_LOG}
   exit 1
fi

# create the lvm snapshot
if ! /usr/sbin/lvcreate -L${SNAPSIZE} -s -n ${SNAPVOL} /dev/${VOLGROUP}/${ORIGVOL}  >/dev/null 2>&1; then
   print_basename "Creating of the LV snapshot failed" 2>&1 | tee -a ${FILE_LAST_LOG}
   exit 1
fi

# check that the mount point does not already exist, mount snapshot
if ! [ -d ${MOUNTDIR}/${ORIGVOL} ]; then
   print_basename "Creating mount point... ${MOUNTDIR}/${ORIGVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
   mkdir -p ${MOUNTDIR}/${ORIGVOL}

   # mount snapshot
   print_basename "Mounting LV snapshot... /dev/${VOLGROUP}/${SNAPVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
   mount /dev/${VOLGROUP}/${SNAPVOL} ${MOUNTDIR}/${ORIGVOL}
   RES=$?

   if [ "$RES" != '0']; then
      print_basename "Cannot mount LV snapshot: /dev/${VOLGROUP}/${SNAPVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
      exit 1
   fi
else
   print_basename "Mount point exists: ${MOUNTDIR}/${ORIGVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
   print_basename "Mounting LV snapshot... /dev/${VOLGROUP}/${SNAPVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
   mount /dev/${VOLGROUP}/${SNAPVOL} ${MOUNTDIR}/${ORIGVOL}
   RES=$?

   if [ "$RES" != '0' ]; then
      print_basename "Cannot mount LV snapshot: /dev/${VOLGROUP}/${SNAPVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
      exit 1
   fi
fi

# main command of the script that does the real stuff
print_basename "Creating backup dir... ${BACKUPDIR}" 2>&1 | tee -a ${FILE_LAST_LOG}
mkdir -p ${BACKUPDIR}

# create tar_exclude_var.txt
if ! [ -f ${SCRIPTDIR}/tar_exclude_var.txt ]; then
   print_basename "creating tar exclude file..." 2>&1 | tee -a ${FILE_LAST_LOG}
   touch ${SCRIPTDIR}/tar_exclude_var.txt
   echo "containerd" >> ${SCRIPTDIR}/tar_exclude_var.txt
   echo 'lost+found' >> ${SCRIPTDIR}/tar_exclude_var.txt
fi

if tar ${TAR_EXCLUDE_VAR} -cvzf ${BACKUPDIR}/${BACKUPNAME} ${MOUNTDIR}/${ORIGVOL}  >/dev/null 2>&1; then
   print_basename "Created TAR archive: ${BACKUPDIR}/${BACKUPNAME}" 2>&1 | tee -a ${FILE_LAST_LOG}
   # md5sum ${BACKUPDIR}/${BACKUPNAME} > ${BACKUPDIR}/${BACKUPNAME}.md5
   RES=0
else
   print_basename "Error: Create TAR archive failed." 2>&1 | tee -a ${FILE_LAST_LOG}
   RES=1

##      exit (1);  # don't remove the snapshot just yet
                   # perhaps we will want to try again ?
fi

if [ "$RES" != '1' ]; then    # prevent removal if error occurred above.
  # umount snapshot
  print_basename "Unmounting LV snapshot..." 2>&1 | tee -a ${FILE_LAST_LOG}
  umount ${MOUNTDIR}/${ORIGVOL}

  # remove snapshot
  if ! /usr/sbin/lvremove -f /dev/${VOLGROUP}/${SNAPVOL} >/dev/null 2>&1; then
     print_basename "cannot remove the LV snapshot: /dev/${VOLGROUP}/${SNAPVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
     RES=1
  else
     print_basename "LV snapshot removed: /dev/${VOLGROUP}/${SNAPVOL}" 2>&1 | tee -a ${FILE_LAST_LOG}
     RES=0
  fi
fi

# find old files and delete
print_basename "Searching for old backups started..." 2>&1 | tee -a ${FILE_LAST_LOG}
COUNT=$(find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUP_DAYS} |wc -l)

if [ "${COUNT}" != 0 ]; then
   print_basename "\"${COUNT}\" old backups will be deleted..." 2>&1 | tee -a ${FILE_LAST_LOG}
   find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUP_DAYS} -delete >> ${FILE_LAST_LOG}
   #find ${SEARCHDIR} -type f -name "*.md5" -mtime +${BACKUP_DAYS} -delete >>  ${FILE_LAST_LOG}
   print_basename "Deleting empty folders..." 2>&1 | tee -a ${FILE_LAST_LOG}
   find ${SEARCHDIR} -empty -type d -delete
else
   print_basename "No old backups were found." 2>&1 | tee -a ${FILE_LAST_LOG}
fi

# show all folders
echo " " 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename "======= Show all backup directories  =======" 2>&1 | tee -a ${FILE_LAST_LOG}
tree -i -d -L 1 ${SEARCHDIR} | sed '/director/d'

print_basename "/------------ End of script ------------/" 2>&1 | tee -a ${FILE_LAST_LOG}
echo " " | tee -a ${FILE_LAST_LOG} 2>&1 | tee -a ${FILE_LAST_LOG}
exit ${RES}

# Examples without variables
#
# /usr/sbin/lvcreate -L5G -s -n var_snap /dev/deb_3cx/opt
# /usr/sbin/lvremove -f /dev/deb_3cx/var_snap
