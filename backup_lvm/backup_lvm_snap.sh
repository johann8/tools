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

VOLGROUP=deb_3cx                                             # name of the volume group
ORIGVOL=var                                                  # name of the logical volume to backup
SNAPVOL=var_snap                                             # name of the snapshot to create
SNAPSIZE=5G                                                  # space to allocate for the snapshot in the volume group
BACKUPDIR="/var/backup/container/$(date '+%Y-%m-%d')"          # where to put the backup
TIMESTAMP="$(date '+%Y%m%d-%Hh%M')"
_DATUM="$(date '+%Y-%m-%d %Hh:%Ms')"
BACKUPNAME="${ORIGVOL}_${TIMESTAMP}.tgz"                     # name of the archive
TAR_EXCLUDE_VAR="--exclude-from=$(pwd)/tar_exclude_var.txt"  # Files to be excluded from tar archive
MOUNTDIR="/mnt/lvm_snap"
SEARCHDIR="/var/backup/container"
LOGFILE="/var/log/container_backup.log"
BACKUPFILES_DELETE=6                                         # Number of backup files 

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

#echo " " >> ${LOGFILE}
echo "Datum: $(date +%Y-%m-%d %Hh %M)"
echo "================================" >> ${LOGFILE}
echo "$(hostname -f)" >>  ${LOGFILE}
echo "================================" >>  ${LOGFILE}
echo "Started at: ${_DATUM}" >>  ${LOGFILE}
echo " " >>  ${LOGFILE}

# only run as root
if [ "$(id -u)" != '0' ]
then
        echo "this script has to be run as root" >>  ${LOGFILE}
        exit 1
fi

# check that the snapshot does not already exist
if [ -e "/dev/${VOLGROUP}/${SNAPVOL}" ]
then
        echo "the lvm snapshot already exists, please destroy it by hand first" >>  ${LOGFILE}
        exit 1
fi

# create the lvm snapshot
if ! /usr/sbin/lvcreate -L${SNAPSIZE} -s -n ${SNAPVOL} /dev/${VOLGROUP}/${ORIGVOL}  >/dev/null 2>&1
then
        echo "creation of the lvm snapshot failed" >>  ${LOGFILE}
        exit 1
fi

# check that the mount point does not already exist, mount snapshot
if ! [ -d ${MOUNTDIR}/${ORIGVOL} ]; then
   echo "creating mount point... ${MOUNTDIR}/${ORIGVOL}" >>  ${LOGFILE}
   mkdir -p ${MOUNTDIR}/${ORIGVOL}

   # mount snapshot
   echo "mounting LVM snapshot... /dev/${VOLGROUP}/${SNAPVOL}" >>  ${LOGFILE}
   mount /dev/${VOLGROUP}/${SNAPVOL} ${MOUNTDIR}/${ORIGVOL}
   RES=$?

   if [ "$RES" != '0']; then
      echo "cannot mount snapshot: /dev/${VOLGROUP}/${SNAPVOL}" >>  ${LOGFILE}
      exit 1
   fi
else
   echo "mount point exists: ${MOUNTDIR}/${ORIGVOL}" >>  ${LOGFILE}
   mount /dev/${VOLGROUP}/${SNAPVOL} ${MOUNTDIR}/${ORIGVOL}
   RES=$?

   if [ "$RES" != '0' ]; then
      echo "cannot mount snapshot: /dev/${VOLGROUP}/${SNAPVOL}" >>  ${LOGFILE}
      exit 1
   fi
fi

# main command of the script that does the real stuff
echo "creating backup dir... ${BACKUPDIR}" >>  ${LOGFILE}
mkdir -p ${BACKUPDIR}
if tar ${TAR_EXCLUDE_VAR} -cvzf ${BACKUPDIR}/${BACKUPNAME} ${MOUNTDIR}/${ORIGVOL}
then
        echo "Created TAR archive: ${BACKUPDIR}/${BACKUPNAME}" >>  ${LOGFILE}
        md5sum ${BACKUPDIR}/${BACKUPNAME} > ${BACKUPDIR}/${BACKUPNAME}.md5
        RES=0
else
        echo "Error: Create TAR archive failed." >>  ${LOGFILE}
        RES=1

##      exit (1);  # don't remove the snapshot just yet
                   # perhaps we will want to try again ?
fi

if [ "$RES" != '1' ]  # prevent removal if error occurred above.
then
  # umount snapshot
  umount ${MOUNTDIR}/${ORIGVOL}

  # remove snapshot
  if ! /usr/sbin/lvremove -f /dev/${VOLGROUP}/${SNAPVOL} >/dev/null 2>&1
  then
        echo "cannot remove the lvm snapshot: /dev/${VOLGROUP}/${SNAPVOL}" >>  ${LOGFILE}
        RES=1
  else
        echo "lvm snapshot removed: /dev/${VOLGROUP}/${SNAPVOL}" >>  ${LOGFILE}
        RES=0
  fi

fi

# find old files and delete
echo "Searching for old files started..." >>  ${LOGFILE}
COUNT=$(find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUPFILES_DELETE} |wc -l)

if [ "${COUNT}" != 0 ]; then
   echo "${COUNT} old files will be deleted..." >>  ${LOGFILE}
   find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUPFILES_DELETE} -delete >>  ${LOGFILE}
   find ${SEARCHDIR} -type f -name "*.md5" -mtime +${BACKUPFILES_DELETE} -delete >>  ${LOGFILE}
   echo "Deleting empty folders..." >>  ${LOGFILE}
   find /var/backup/container/ -empty -type d -delete
else
   echo "No old files were found." >>  ${LOGFILE}
fi

echo "--------------------------------" >> ${LOGFILE}
echo " " >>  ${LOGFILE}
exit ${RES}

# Examples without variables
#
# /usr/sbin/lvcreate -L5G -s -n var_snap /dev/deb_3cx/opt
# /usr/sbin/lvremove -f /dev/deb_3cx/var_snap
