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
# Last update : 03.08.2022                                                   #
# Version     : 1.01                                                         #
#                                                                            #
# Author      : Johann Hahn, <j.hahn@wassermannkabeltechnik.de>              #
# DokuWiki    : https://docu.int.wassermanngruppe.de                         #
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
#                                H I S T O R Y                               #
##############################################################################
# -------------------------------------------------------------------------- #
# Version     : 1.01                                                         #
# Description : Changed var area                                             #
# -------------------------------------------------------------------------- #
# -------------------------------------------------------------------------- #
# Version     : x.xx                                                         #
# Description : <Description>                                                #
# -------------------------------------------------------------------------- #
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
SCRIPT_VERSION="0.1.3"
#BASENAME="${0##*/}"
SCRIPTDIR="${0%/*}"
BACKUPDIR="/mnt/NAS_BareOS/docker/$(hostname -s)/lvm-snapshot/$(date "+%Y-%m-%d")"  # where to put the backup
TIMESTAMP="$(date +%Y%m%d-%Hh%M)"
_DATUM="$(date '+%Y-%m-%d %Hh:%Ms')"
BACKUPNAME="${ORIGVOL}_${TIMESTAMP}.tgz"                           # name of the archive
TAR_EXCLUDE_VAR="--exclude-from=${SCRIPTDIR}/tar_exclude_var.txt"  # Files to be excluded from tar archive
MOUNTDIR="/mnt/lvm_snap"
SEARCHDIR="${BACKUPDIR%/*}"
LOGFILE="/var/log/container_backup.log"
BACKUPFILES_DELETE=6                                                # Number of backup files

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

#
### ============= Main script ============
#

echo -e "\n"
print_basename "Script version is: \"${SCRIPT_VERSION}\"" | tee -a ${LOGFILE}
print_basename "Datum: $(date "+%Y-%m-%d")" | tee -a ${LOGFILE}
print_basename "============================" | tee -a ${LOGFILE}
print_basename " Run backup of LV snapshot" | tee -a ${LOGFILE}
print_basename "============================" | tee -a ${LOGFILE}
print_basename "Started on \"$(hostname -f)\" at \"${_DATUM}\"" | tee -a ${LOGFILE}
echo " " | tee -a ${LOGFILE}


# only run as root
if [ "$(id -u)" != '0' ]; then
   print_basename "This script has to be run as root" | tee -a ${LOGFILE}
   exit 1
fi

# check that the snapshot does not already exist
if [ -e "/dev/${VOLGROUP}/${SNAPVOL}" ]; then
   print_basename "LV snapshot already exists, please destroy it by hand first" | tee -a  ${LOGFILE}
   exit 1
fi

# create the lvm snapshot
if ! /usr/sbin/lvcreate -L${SNAPSIZE} -s -n ${SNAPVOL} /dev/${VOLGROUP}/${ORIGVOL}  >/dev/null 2>&1; then
   print_basename "Creating of the LV snapshot failed" 2>&1 >> ${LOGFILE}
   exit 1
fi

# check that the mount point does not already exist, mount snapshot
if ! [ -d ${MOUNTDIR}/${ORIGVOL} ]; then
   print_basename "Creating mount point... ${MOUNTDIR}/${ORIGVOL}" | tee -a ${LOGFILE}
   mkdir -p ${MOUNTDIR}/${ORIGVOL}

   # mount snapshot
   print_basename "Mounting LV snapshot... /dev/${VOLGROUP}/${SNAPVOL}" | tee -a ${LOGFILE}
   mount /dev/${VOLGROUP}/${SNAPVOL} ${MOUNTDIR}/${ORIGVOL}
   RES=$?

   if [ "$RES" != '0']; then
      print_basename "Cannot mount LV snapshot: /dev/${VOLGROUP}/${SNAPVOL}" | tee -a ${LOGFILE}
      exit 1
   fi
else
   print_basename "Mount point exists: ${MOUNTDIR}/${ORIGVOL}" | tee -a ${LOGFILE}
   print_basename "Mounting LV snapshot... /dev/${VOLGROUP}/${SNAPVOL}" | tee -a ${LOGFILE}
   mount /dev/${VOLGROUP}/${SNAPVOL} ${MOUNTDIR}/${ORIGVOL}
   RES=$?

   if [ "$RES" != '0' ]; then
      print_basename "Cannot mount LV snapshot: /dev/${VOLGROUP}/${SNAPVOL}" | tee -a ${LOGFILE}
      exit 1
   fi
fi

# main command of the script that does the real stuff
print_basename "Creating backup dir... ${BACKUPDIR}" | tee -a ${LOGFILE}
mkdir -p ${BACKUPDIR}

# create tar_exclude_var.txt
if ! [ -f ${SCRIPTDIR}/tar_exclude_var.txt ]; then
   print_basename "creating tar exclude file..." | tee -a ${LOGFILE}
   touch ${SCRIPTDIR}/tar_exclude_var.txt
   echo "containerd" >> ${SCRIPTDIR}/tar_exclude_var.txt
   echo 'lost+found' >> ${SCRIPTDIR}/tar_exclude_var.txt
fi

if tar ${TAR_EXCLUDE_VAR} -cvzf ${BACKUPDIR}/${BACKUPNAME} ${MOUNTDIR}/${ORIGVOL}  >/dev/null 2>&1; then
   print_basename "Created TAR archive: ${BACKUPDIR}/${BACKUPNAME}" | tee -a ${LOGFILE}
   # md5sum ${BACKUPDIR}/${BACKUPNAME} > ${BACKUPDIR}/${BACKUPNAME}.md5
   RES=0
else
   print_basename "Error: Create TAR archive failed." | tee -a ${LOGFILE}
   RES=1

##      exit (1);  # don't remove the snapshot just yet
                   # perhaps we will want to try again ?
fi

if [ "$RES" != '1' ]; then    # prevent removal if error occurred above.
  # umount snapshot
  print_basename "Unmounting LV snapshot..." | tee -a ${LOGFILE}
  umount ${MOUNTDIR}/${ORIGVOL}

  # remove snapshot
  if ! /usr/sbin/lvremove -f /dev/${VOLGROUP}/${SNAPVOL} >/dev/null 2>&1; then
     print_basename "cannot remove the LV snapshot: /dev/${VOLGROUP}/${SNAPVOL}" | tee -a ${LOGFILE}
     RES=1
  else
     print_basename "LV snapshot removed: /dev/${VOLGROUP}/${SNAPVOL}" | tee -a ${LOGFILE}
     RES=0
  fi
fi

# find old files and delete
print_basename "Searching for old backups started..." | tee -a ${LOGFILE}
COUNT=$(find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUPFILES_DELETE} |wc -l)

if [ "${COUNT}" != 0 ]; then
   print_basename "\"${COUNT}\" old backups will be deleted..." | tee -a ${LOGFILE}
   find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUPFILES_DELETE} -delete >> ${LOGFILE}
   #find ${SEARCHDIR} -type f -name "*.md5" -mtime +${BACKUPFILES_DELETE} -delete >>  ${LOGFILE}
   print_basename "Deleting empty folders..." | tee -a ${LOGFILE}
   find ${SEARCHDIR} -empty -type d -delete
else
   print_basename "No old backups were found." | tee -a ${LOGFILE}
fi

# show all folders
echo " "
print_basename "======= Show all backup directories  ======="
tree -i -d -L 1 ${SEARCHDIR} | sed '/director/d'

print_basename "/------------ End of script ------------/" | tee -a ${LOGFILE}
echo " " | tee -a ${LOGFILE}
exit ${RES}

# Examples without variables
#
# /usr/sbin/lvcreate -L5G -s -n var_snap /dev/deb_3cx/opt
# /usr/sbin/lvremove -f /dev/deb_3cx/var_snap
