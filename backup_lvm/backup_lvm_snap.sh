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
# Last update : 19.02.2025                                                   #
# Version     : 0.2.6                                                        #
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
# Copyright (c) 2022 - 2024 by Johann Hahn                                   #
#                                                                            #
##############################################################################

##############################################################################
# >>> Please edit following lines for personal settings and custom usages. ! #
##############################################################################

# CUSTOM LV vars - please adjusti
LVM_PARTITION_DOCKER=yes                            # is there LVM Partition for docker container: yes | no
LV_DOCKER_NAME=opt                                  # Docker containers are installed on the Logical Volume named "opt". If empty, the containers will not be stopped.
VOLGROUP=rl_vmd63899                                # lvdisplay: name of the volume group
LV_NAME=opt,var                                     # lvdisplay: name of the logical volume to backup. Getrennt mit Komma oder Leerzeichen
SNAP_SUFFIX=snap                                    #
SNAP_LV_NAME=opt_${SNAP_SUFFIX},var_${SNAP_SUFFIX}  # name of logical volume snapshot. Getrennt mit Komma oder Leerzeichen
SNAPSIZE=1G                                         # space to allocate for the snapshot in the volume group
MOUNTDIR="/mnt/lvm_snap"                            # Path to mount point of lv snapshot
MOUNT_OPTIONS="-o nouuid"                           # Mount option for xfs FS

# CUSTOM - script
SCRIPT_NAME="backupLVS.sh"
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.2.6"
SCRIPT_START_TIME=$SECONDS                          # Script start time

# CUSTOM - vars
#BASENAME="${0##*/}"
SCRIPTDIR="${0%/*}"
BACKUPDIR="/var/backup/docker/$(hostname -s)/lvm-snapshot/$(date "+%Y-%m-%d_%Hh-%Mm")"  # where to put the backup
TIMESTAMP="$(date +%Y%m%d-%Hh%Mm)"
_DATUM="$(date '+%Y-%m-%d %Hh:%Mm:%Ss')"
BACKUPNAME="${LV_NAME}_${TIMESTAMP}.tgz"                                        # name of the archive
TAR_EXCLUDE_VAR="--exclude-from=${SCRIPTDIR}/tar_exclude_var.txt"               # Files|folders to be excluded from tar archive
SEARCHDIR="${BACKUPDIR%/*}"

# only if Bacula is used, otherwise comment 
AR_EXCLUDE_B_CONTAINER=(bacularis bacula-db bacula-smtpd)                       # Array - exclude bacula container

# CUSTOM - logs
FILE_LAST_LOG='/tmp/'${SCRIPT_NAME}'.log'
FILE_MAIL='/tmp/'${SCRIPT_NAME}'.mail'

# CUSTOM - Send mail
MAIL_STATUS='Y'                                                                 # Send Status-Mail [Y|N]
PROG_SENDMAIL='/sbin/sendmail'
VAR_HOSTNAME=$(uname -n)
VAR_SENDER='root@'${VAR_HOSTNAME}
VAR_EMAILDATE=$(date '+%a, %d %b %Y %H:%M:%S (%Z)')

# CUSTOM - Mail-Recipient.
MAIL_RECIPIENT='admin@myfirma.de'

# CUSTOM - Days number of stored backups
BACKUP_DAYS=6

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

SYSTEMCTL_COMMAND=`command -v systemctl`
LVREMOVE_COMMAND=`command -v lvremove`
LVCREATE_COMMAND=`command -v lvcreate`
LVDISPLAY_COMMAND=`command -v lvdisplay`
MOUNT_COMMAND=`command -v mount`
UMOUNT_COMMAND=`command -v umount`

#
### === Functions ===
#

# Function print script basename
#echo -e() {
#   echo -e "${BASENAME}: $1"
#}

# Stop monit service
stop_monit_service() {
   if [ ${S_MONIT} == 1 ]; then
      echo -e "Info: Stopping monit service ..." | tee -a ${FILE_LAST_LOG}
      ${SYSTEMCTL_COMMAND} stop monit

      if [ $? == 0 ]; then
         echo -e "Info: Monit service was successfully stopped. \n" | tee -a ${FILE_LAST_LOG}
      else
         echo -e "Error: Monit service could not be stopped. \n" | tee -a ${FILE_LAST_LOG}
      fi
   fi
}

# Start monit service
start_monit_service() {
   if [ ${S_MONIT} == 1 ]; then
      echo -e "Info: Starting monit service ..." | tee -a ${FILE_LAST_LOG}
      ${SYSTEMCTL_COMMAND} start monit

      if [ $? == 0 ]; then
         echo -e "Info: Monit service was successfully started. \n" | tee -a ${FILE_LAST_LOG}
      else
         echo -e "Error: Monit service could not be started. \n" | tee -a ${FILE_LAST_LOG}
      fi
   fi
}

# Docker state message
print_container_state() {
   if [ "${DOCSTATE}" == "false" ]; then
      echo -e "${1}" | tee -a ${FILE_LAST_LOG}
   else
      echo -e "${2}" | tee -a ${FILE_LAST_LOG}
   fi
}

# Stop docker containers
stop_docker_container() {
   if [ -n "$CONTAINERS" ]; then
      for container in $CONTAINERS; do
         CONTAINER_COUNTER=$((CONTAINER_COUNTER+1))
         CONTAINER_NAME=$(docker inspect --format '{{.Name}}' $container | sed 's/^\///')

      # skip container"bacula-smtpd bacularis bacula-db"
      if [[ ${CONTAINER_NAME} =  ${AR_EXCLUDE_B_CONTAINER[0]} ]] || [[ ${CONTAINER_NAME} = ${AR_EXCLUDE_B_CONTAINER[1]} ]] || [[ ${CONTAINER_NAME} = ${AR_EXCLUDE_B_CONTAINER[2]} ]]; then
         echo -e "Info: Container \"${CONTAINER_NAME}\" will be skipped ..." | tee -a ${FILE_LAST_LOG}
      else
         echo -e "Info: Stopping container ($CONTAINER_COUNTER/$TOTAL_CONTAINERS): ${CONTAINER_NAME} ($container) ..." | tee -a ${FILE_LAST_LOG}
         docker stop $container > /dev/null 2>&1

         DOCSTATE=$(docker inspect -f {{.State.Running}} $container)
         echo -e "Info: Container running state: ${DOCSTATE}" | tee -a ${FILE_LAST_LOG}
         print_container_state "Info: Container stopped." "Info: Container ${CONTAINER_NAME} ($container) still not running, should be started!!!"
      fi
      echo -e "....................................................." | tee -a ${FILE_LAST_LOG}
      echo -e " " | tee -a ${FILE_LAST_LOG}
      done
   else
      echo -e "Info: No Docker containers found." | tee -a ${FILE_LAST_LOG}
   fi
}

# Start docker containers
start_docker_container() {
   if [ -n "$CONTAINERS" ]; then
      for container in $CONTAINERS; do
         CONTAINER_COUNTER=$((CONTAINER_COUNTER+1))
         CONTAINER_NAME=$(docker inspect --format '{{.Name}}' $container | sed 's/^\///')

         # skip container Bacula
         if [[ ${CONTAINER_NAME} =  ${AR_EXCLUDE_B_CONTAINER[0]} ]] || [[ ${CONTAINER_NAME} = ${AR_EXCLUDE_B_CONTAINER[1]} ]] || [[ ${CONTAINER_NAME} = ${AR_EXCLUDE_B_CONTAINER[2]} ]]; then
            echo -e "Info: Container \"${CONTAINER_NAME}\" will be skipped ..." | tee -a ${FILE_LAST_LOG}
         else
            echo -e "Info: Starting container ($CONTAINER_COUNTER/$TOTAL_CONTAINERS): ${CONTAINER_NAME} ($container) ..." | tee -a ${FILE_LAST_LOG}
            docker start $container > /dev/null 2>&1

            DOCSTATE=$(docker inspect -f {{.State.Running}} $container)
            echo -e "Info: Container running state: ${DOCSTATE}" | tee -a ${FILE_LAST_LOG}
            print_container_state "Info: Container ${CONTAINER_NAME} ($container) still not running, should be started!!!" "Info: Container started."
         fi
            echo -e "....................................................." | tee -a ${FILE_LAST_LOG}
            echo -e " " | tee -a ${FILE_LAST_LOG} 
      done
   else
      echo -e "Info: No Docker containers found." | tee -a ${FILE_LAST_LOG}
   fi
}

# Umount and remove LVM snapshot
remove_lvm_snapshot() {
   if [ -e "/dev/${VOLGROUP}/$1" ]; then
      echo " " | tee -a ${FILE_LAST_LOG}
      echo -e "Info: LVM snapshot \"$1\" exists. It will be destroyed." | tee -a ${FILE_LAST_LOG}

      # check if snapshot mounted
      if [[ $(df -hT | grep ${MOUNTDIR}/$1) ]]; then
         # umount snapshot
         echo -e "Info: Unmounting LV snapshot \"$1\" ..." | tee -a ${FILE_LAST_LOG}
         ${UMOUNT_COMMAND} ${MOUNTDIR}/$1
         RES=$?

         if [ "$RES" != '0' ]; then
            echo -e "Error: Cannot unmount LVM snapshot \"$1\"." | tee -a ${FILE_LAST_LOG}
            exit 0
         else
            # remove snapshot
            if ! ${LVREMOVE_COMMAND} -f /dev/${VOLGROUP}/$1 >/dev/null 2>&1; then
               echo -e "Error: Cannot remove the LV snapshot \"/dev/${VOLGROUP}/$1\"" | tee -a ${FILE_LAST_LOG}
               exit 0
            else
               echo -e "Info: LV snapshot removed \"/dev/${VOLGROUP}/$1\"" | tee -a ${FILE_LAST_LOG}
            fi
         fi
      else
         # remove snapshot
         if ! ${LVREMOVE_COMMAND} -f /dev/${VOLGROUP}/$1 >/dev/null 2>&1; then
            echo -e "Error: Cannot remove the LV snapshot \"/dev/${VOLGROUP}/$1\"" | tee -a ${FILE_LAST_LOG}
            exit 0
         else
            echo -e "Info: LV snapshot removed \"/dev/${VOLGROUP}/$1\"" | tee -a ${FILE_LAST_LOG}
         fi 
      fi
   fi
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
echo -e "\n" 2>&1 > ${FILE_LAST_LOG}
echo -e "Started on \"$(hostname -f)\" at \"${_DATUM}\"" 2>&1 | tee -a ${FILE_LAST_LOG}
echo -e "Script version is: \"${SCRIPT_VERSION}\"" 2>&1 | tee -a ${FILE_LAST_LOG}
# echo -e "Datum: $(date "+%Y-%m-%d")" 2>&1 | tee -a ${FILE_LAST_LOG}
echo -e "===========================" 2>&1 | tee -a ${FILE_LAST_LOG}
echo -e " Run backup of LV snapshot" 2>&1 | tee -a ${FILE_LAST_LOG}
echo -e "===========================" 2>&1 | tee -a ${FILE_LAST_LOG}
echo " " 2>&1 | tee -a ${FILE_LAST_LOG}

# only run as root
if [ "$(id -u)" != '0' ]; then
   echo -e "Error: This script has to be run as root." 2>&1 | tee -a ${FILE_LAST_LOG}
   exit 0
fi

# check if service monit is available.
if [[ -x /usr/local/bin/monit ]]; then
   echo -e "Info: Monit service is available." | tee -a ${FILE_LAST_LOG}
   S_MONIT=1
else
   echo -e "Error: Monit service is not available." | tee -a ${FILE_LAST_LOG}
   S_MONIT=0
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${SYSTEMCTL_COMMAND}" ]; then
   echo -e "Error: Command \"${SYSTEMCTL_COMMAND}\" is not available. \n" | tee -a ${FILE_LAST_LOG}
else
   echo -e "Info: Command \"${SYSTEMCTL_COMMAND}\" is available. \n" | tee -a ${FILE_LAST_LOG}
fi

# Create array 
LV_NAME_AR=($(echo ${LV_NAME} |sed -e 's/,/ /'));             # echo ${LV_NAME_AR[*]}
SNAP_LV_NAME_AR=($(echo ${SNAP_LV_NAME} |sed -e 's/,/ /'));   # echo ${SNAP_LV_NAME_AR[*]}

#
### if a LVM partition for docker container exists, then a snapshot will be created and only then the backup is executed
#
if [[ "${LVM_PARTITION_DOCKER}" == "yes" ]]; then

   # Create LV Snapshot
   for i in ${LV_NAME_AR[*]}; do

      # check, that the snapshot does not already exist and remove it
      remove_lvm_snapshot ${i}_${SNAP_SUFFIX}

      # Stop docker container, if i=opt
      if [[ "${i}" == "${LV_DOCKER_NAME}" ]]; then

       	 # stop monit service
         stop_monit_service 

         # stop docker container
         echo -e "Info: Found $(docker ps -aq | wc -l) Docker containers." | tee -a ${FILE_LAST_LOG}
         echo -e "Info: Stopping all docker containers ..." | tee -a ${FILE_LAST_LOG}
         CONTAINERS=$(docker ps -aq)
         TOTAL_CONTAINERS=$(echo "$CONTAINERS" | wc -w)
         CONTAINER_COUNTER=0
         echo -e "....................................................." | tee -a ${FILE_LAST_LOG}
         stop_docker_container
		 
         # Set var STOP_RES=0, if docker container stopped
         STOP_RES=0
      fi

      # create the lvm snapshot
      if ! ${LVCREATE_COMMAND} -L${SNAPSIZE} -s -n ${i}_${SNAP_SUFFIX} /dev/${VOLGROUP}/${i}  >/dev/null 2>&1; then
         echo -e "Error: Creating of the LVM snapshot \"${i}_${SNAP_SUFFIX}\" failed" | tee -a ${FILE_LAST_LOG}
         exit 0
      else
         echo -e "Info: LVM snapshot \"${i}_${SNAP_SUFFIX}\" was successfully created." | tee -a ${FILE_LAST_LOG}

         # Check LV snap state (active | INACTIVE)
         LVM_SNAP_STATE=$(${LVDISPLAY_COMMAND} /dev/${VOLGROUP}/${i}_${SNAP_SUFFIX} |grep 'LV snapshot status' |awk '{print $4}')
         if [[ ${LVM_SNAP_STATE} == 'active' ]]; then
            echo -e "Info: LVM snapshot \"${i}_${SNAP_SUFFIX}\" state is \"active\"." | tee -a ${FILE_LAST_LOG}
         else
            echo -e "Error: LVM snapshot \"${i}_${SNAP_SUFFIX}\" state is \"INACTIVE\"." | tee -a ${FILE_LAST_LOG}
            echo -e "Info: The wrong size of LVM snapshot \"${i}_${SNAP_SUFFIX}\" was chosen." | tee -a ${FILE_LAST_LOG}
            exit 0
         fi
      fi

      # check that the mount point does not already exist, mount snapshot MOUNTDIR="/mnt/lvm_snap"
      if ! [ -d ${MOUNTDIR}/${i} ]; then
         # create mount point
         # echo " " | tee -a ${FILE_LAST_LOG}
         echo -e "Info: Creating mount point \"${MOUNTDIR}/${i}\" ... " | tee -a ${FILE_LAST_LOG}
         mkdir -p ${MOUNTDIR}/${i}
      else
         # echo " " | tee -a ${FILE_LAST_LOG}
         echo -e "Info: Mount point exists \"${MOUNTDIR}/${i}\"" | tee -a ${FILE_LAST_LOG}
      fi

      # check if FS ist XFS
      FS_XFS=$(df -hT | grep -w "dev" | grep -w "$i" | awk '{print $2}')

      if [ "${FS_XFS}" = "xfs" ]; then
         # mount snapshot
         echo -e "Info: Mounting LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" ... "  | tee -a ${FILE_LAST_LOG}
         ${MOUNT_COMMAND} ${MOUNT_OPTIONS} /dev/${VOLGROUP}/${i}_${SNAP_SUFFIX} ${MOUNTDIR}/${i}
         RES=$?

         if [ "$RES" != '0' ]; then
            echo -e "Error: Cannot mount LVM snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\"" | tee -a ${FILE_LAST_LOG}
            exit 0
         else
            echo -e "Info: LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" was successfully mounted. \n" | tee -a ${FILE_LAST_LOG}
         fi
      else
         # mount snapshot
         echo -e "Info: Mounting LVM snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" ... " | tee -a ${FILE_LAST_LOG}
         ${MOUNT_COMMAND} /dev/${VOLGROUP}/${i}_${SNAP_SUFFIX} ${MOUNTDIR}/${i}
         RES=$?

         if [ "$RES" != '0' ]; then
            echo -e "Error: Cannot mount LVM snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\"" | tee -a ${FILE_LAST_LOG}
            exit 0
         else
            echo -e "Info: LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" was successfully mounted. \n" | tee -a ${FILE_LAST_LOG}
         fi
      fi
   done
   # Set var SNAP_RES
   SNAP_RES=0
else
   echo -e "Info: There is no LVM Partition for docker container." | tee -a ${FILE_LAST_LOG}
fi

#
### Run docker container, start monit, create backup, unmount and remove snapshot
#
if [ "${SNAP_RES}" = '0' ]; then
   
   # Start docker container, if STOP_RES=0
   if [[ "${STOP_RES}" = '0' ]]; then

      # stop docker container
      echo -e "Info: Found $(docker ps -aq | wc -l) Docker containers." | tee -a ${FILE_LAST_LOG}
      echo -e "Info: Starting all stopped docker containers ... " | tee -a ${FILE_LAST_LOG} 
      CONTAINERS=$(docker ps -aq)
      TOTAL_CONTAINERS=$(echo "$CONTAINERS" | wc -w)
      CONTAINER_COUNTER=0
      echo -e "....................................................." | tee -a ${FILE_LAST_LOG}
      start_docker_container
   fi 

   # Start monit service
   #echo -e " " | tee -a ${FILE_LAST_LOG}
   start_monit_service
   echo -e " " | tee -a ${FILE_LAST_LOG}

   # main command of the script that does the real stuff
   echo -e "Info: Creating backup dir \"${BACKUPDIR}\" ... " 2>&1 | tee -a ${FILE_LAST_LOG}
   mkdir -p ${BACKUPDIR}

   # create tar_exclude_var.txt
   if ! [ -f ${SCRIPTDIR}/tar_exclude_var.txt ]; then
      echo -e "Info: Creating tar exclude file ... " 2>&1 | tee -a ${FILE_LAST_LOG}
      touch ${SCRIPTDIR}/tar_exclude_var.txt
      echo "containerd" >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'lost+found' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'eff.org' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'overlay2' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'builder' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'buildkit' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'containers' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'image' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'plugins' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'runtimes' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'swarm' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'trust' >> ${SCRIPTDIR}/tar_exclude_var.txt
      echo 'tmp' >> ${SCRIPTDIR}/tar_exclude_var.txt
   fi

   # Make backup
   for i in ${LV_NAME_AR[*]}; do
 
      # Set var BACKUPNAME
      BACKUPNAME="${i}_${TIMESTAMP}.tgz" 	  

      echo -e "Info: Running backup \"${i}\" ..."
      # Create backup
      if [ -n ${LV_DOCKER_NAME} ] && [[ "${i}" == "var" ]]; then 
 
         # Run backup
         if tar ${TAR_EXCLUDE_VAR} -cvzf ${BACKUPDIR}/${BACKUPNAME} ${MOUNTDIR}/${i}/lib/docker/ > /dev/null 2>&1; then
         # for debug
         #if ls -la > /dev/null 2>&1; then
            echo -e "Info: Created TAR archive: \"${BACKUPDIR}/${BACKUPNAME}\"" 2>&1 | tee -a ${FILE_LAST_LOG}

            # Determine archive size
            ARCHVE_SIZE=$(ls -lh ${BACKUPDIR}/${BACKUPNAME} | awk '{print $5}')

            echo -e "The archive size of \"${BACKUPNAME}\" is: ${ARCHVE_SIZE}" 2>&1 | tee -a ${FILE_LAST_LOG}

            # md5sum ${BACKUPDIR}/${BACKUPNAME} > ${BACKUPDIR}/${BACKUPNAME}.md5
            T_RES=0
         else
            echo -e "Error: Creating TAR archive \"${BACKUPDIR}/${BACKUPNAME} failed." 2>&1 | tee -a ${FILE_LAST_LOG}
            exit 0
         fi
      else
         # Run backup
         if tar -cvzf ${BACKUPDIR}/${BACKUPNAME} ${MOUNTDIR}/${i} > /dev/null 2>&1; then
         # for debug
         #if ls -la > /dev/null 2>&1; then
            echo -e "Info: Created TAR archive: \"${BACKUPDIR}/${BACKUPNAME}\"" 2>&1 | tee -a ${FILE_LAST_LOG}

            # Determine archive size
            ARCHVE_SIZE=$(ls -lh ${BACKUPDIR}/${BACKUPNAME} | awk '{print $5}')

            echo -e "The archive size of \"${BACKUPNAME}\" is: ${ARCHVE_SIZE}" 2>&1 | tee -a ${FILE_LAST_LOG}
            # md5sum ${BACKUPDIR}/${BACKUPNAME} > ${BACKUPDIR}/${BACKUPNAME}.md5
            T_RES=0
         else
            echo -e "Error: Creating TAR archive \"${BACKUPDIR}/${BACKUPNAME} failed." 2>&1 | tee -a ${FILE_LAST_LOG}
            exit 0
         fi
      fi

      # unmount and remove snapshot 
      if [ "${T_RES}" = '0' ]; then    # prevent removal if error occurred above.
         # umount snapshot
         echo -e "Info: Unmounting LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" ... " 2>&1 | tee -a ${FILE_LAST_LOG}
         ${UMOUNT_COMMAND} ${MOUNTDIR}/${i}
         U_RES=$?

         # remove snapshot
         if [ "${U_RES}" = '0' ]; then
            # Unmount success message
            echo -e "Info: LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" was successfully unmounted."
             
            # remove LV snapshot
            if ! /usr/sbin/lvremove -f /dev/${VOLGROUP}/${i}_${SNAP_SUFFIX} >/dev/null 2>&1; then
               echo -e "Error: Cannot remove LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\"" 2>&1 | tee -a ${FILE_LAST_LOG}
               exit 0
            else
               echo -e "Info: LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" successfully removed." 2>&1 | tee -a ${FILE_LAST_LOG}
               echo -e " " | tee -a ${FILE_LAST_LOG}
            fi
         #else
            #echo -e "Error: Unmounting LV snapshot \"/dev/${VOLGROUP}/${i}_${SNAP_SUFFIX}\" failed."
         fi
      fi
   done
   # Set var B_RES
   B_RES=0
fi

# find old files and delete
if [ "${B_RES}" = '0' ]; then
   echo -e "Searching for old backups started ..." 2>&1 | tee -a ${FILE_LAST_LOG}
   COUNT=$(find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUP_DAYS} |wc -l)

   if [ "${COUNT}" != 0 ]; then
      echo -e "\"${COUNT}\" old backups will be deleted ..." 2>&1 | tee -a ${FILE_LAST_LOG}
      find ${SEARCHDIR} -type f -name "*.tgz" -mtime +${BACKUP_DAYS} -delete >> ${FILE_LAST_LOG}
      #find ${SEARCHDIR} -type f -name "*.md5" -mtime +${BACKUP_DAYS} -delete >>  ${FILE_LAST_LOG}
      echo -e "Deleting empty folders ..." 2>&1 | tee -a ${FILE_LAST_LOG}
      find ${SEARCHDIR} -empty -type d -delete
   else
      echo -e "No old backups were found." 2>&1 | tee -a ${FILE_LAST_LOG}
   fi
fi

# show all folders
(
echo " "
echo -e "======= Show all backup directories  ======="
tree -i -d -L 1 ${SEARCHDIR} | sed '/director/d'
) 2>&1 | tee -a ${FILE_LAST_LOG}

# print "end of script"
echo -e "/------------ Script ended at: \"${_DATUM}\" ------------/" 2>&1 | tee -a ${FILE_LAST_LOG}

# Script run time calculate
#
#SCRIPT_START_TIME=$SECONDS
SCRIPT_END_TIME=$SECONDS
let deltatime=SCRIPT_END_TIME-SCRIPT_START_TIME
let hours=deltatime/3600
let minutes=(deltatime/60)%60
let seconds=deltatime%60
printf "Time elapsed: %d:%02d:%02d\n" $hours $minutes $seconds 2>&1 | tee -a ${FILE_LAST_LOG}
echo -e " " 2>&1 | tee -a ${FILE_LAST_LOG}

### Send status e-mail
if [ ${MAIL_STATUS} = 'Y' ]; then
   echo -e "Sending staus mail ... " 2>&1 | tee -a ${FILE_LAST_LOG}
   sendmail STATUS
fi

exit ${B_RES}


# Examples without variables
#
# /usr/sbin/lvcreate -L5G -s -n var_snap /dev/deb_3cx/opt
# /usr/sbin/lvremove -f /dev/deb_3cx/var_snap

# chmod 0700 /usr/local/bin/backupLVS.sh
# Achtung add PATH to crontab:
# echo $PATH
# crontab -e
# -----
# PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
#
# # LVM snapshot of "opt": /mnt/nfsStorage/$(hostname -s)/lvm-snapshot
# 15  23  *  *  *  /usr/local/bin/backupLVS.sh > /dev/null 2>&1
# ------
