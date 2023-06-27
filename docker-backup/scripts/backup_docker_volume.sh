#!/bin/bash
#
#set -x

# Usage:
# No script argument - make volume backup of all docker containers
#
# Script argument - make volume backup entered docker container
# You must enter the Container ID
# Container IDs must be separated from each other with a space character: ./scipt.sh ContainerID1 ContainerID2 ContainerID3

#
### === Set Variables ===
#

# CUSTOM - script
SCRIPT_NAME="backupDCV.sh"                      # DCV - docker container volume
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.1.6"

# CUSTOM - vars
TIMESTAMP=$(date +%F_%H-%M)
TIMESTAMP1=$(date "+%Y-%m-%d %H:%M:%S")
BACKUP_PATH=/mnt/NFS_PBS01/docker/$(hostname -s)/volume-backup/${TIMESTAMP}
FILE_EXTENSION=tgz                              # Valid: tzst | tar.zst | tar.zstd | tgz | tar.gz | tbz2 | tar.bz2
IMAGE_NAME="johann8/dcbackup"
TAR_OPTIONS="--exclude=/opt/bacula/archive/*"   # Bacula storage folder as example


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
BACKUP_DAYS=7

#
### === Functions ===
#

# Function: print script name
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

# check script arguments
if [[ -z $1 ]]; then
   # No script argument - make volume backup of all docker containers
   CONTAINER_ID=$(docker ps -q)
else
   # script argument - make volume backup entered docker container
   CONTAINER_ID=$(echo $@)
fi

### check if docker image loaded and up to date
echo -e "\n"
print_basename "Script version is: \"${SCRIPT_VERSION}\"" 2>&1 | tee  ${FILE_LAST_LOG}
docker images -a |grep ${IMAGE_NAME}
if [ $? == 0 ]; then
   print_basename "There is a docker image \"${IMAGE_NAME}\"" 2>&1 | tee -a ${FILE_LAST_LOG}

   # check if image is recent
   RUNNING_IMAGE="$(docker inspect --format "{{.Id}}" --type image "${IMAGE_NAME}")"
   docker pull ${IMAGE_NAME} 2> /dev/null
   LATEST_IMAGE="$(docker inspect --format "{{.Id}}" --type image "${IMAGE_NAME}")"

   if ! [ ${RUNNING_IMAGE} = ${LATEST_IMAGE} ]; then
      print_basename "There is a more recent docker image \"${IMAGE_NAME}\"" 2>&1 | tee -a ${FILE_LAST_LOG}
      print_basename "Removing old image \"${IMAGE_NAME}\"... " 2>&1 | tee -a ${FILE_LAST_LOG}
      docker rmi ${IMAGE_NAME}
      print_basename "Downloading image \"${IMAGE_NAME}\"... " 2>&1 | tee -a ${FILE_LAST_LOG}
      echo "" 2>&1 | tee -a ${FILE_LAST_LOG}
      docker pull ${IMAGE_NAME}
   else
      #echo "" 2>&1 | tee -a ${FILE_LAST_LOG}
      print_basename "The docker image \"${IMAGE_NAME}\" is up to date." 2>&1 | tee -a ${FILE_LAST_LOG}
   fi
else
   print_basename "There is no docker image \"${IMAGE_NAME}\"" 2>&1 | tee -a ${FILE_LAST_LOG}
   print_basename "Downloading image \"${IMAGE_NAME}\"... " 2>&1 | tee -a ${FILE_LAST_LOG}
   docker pull ${IMAGE_NAME}
fi

# print start message
echo "" 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename "+------------------------------------------------------------------------------------------+" 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename "| Start docker volume backup on host: \"$(hostname -f)\" at \"${TIMESTAMP1}\" |" 2>&1 | tee -a ${FILE_LAST_LOG}
print_basename "+------------------------------------------------------------------------------------------+" 2>&1 | tee -a ${FILE_LAST_LOG}

### Create docker volume backup
for i in `docker inspect --format='{{.Name}}' ${CONTAINER_ID} | cut -f2 -d\/`; do
   echo " " 2>&1 | tee -a ${FILE_LAST_LOG}
   CONTAINER_NAME=$i
   mkdir -p ${BACKUP_PATH}/${CONTAINER_NAME}
   print_basename "|---------- Backing up volumes of container \"${CONTAINER_NAME}\" ----------|" 2>&1 | tee -a ${FILE_LAST_LOG}

   (
   echo -n -e "\"${CONTAINER_NAME}\" - "
   docker run --rm --userns=host \
   --volumes-from ${CONTAINER_NAME} \
   -v ${BACKUP_PATH}:/backup \
   -e TAR_OPTS="${TAR_OPTIONS}" \
   johann8/dcbackup:latest \
   backup "${CONTAINER_NAME}/${CONTAINER_NAME}-volume.backup.${FILE_EXTENSION}"
   ) 2>&1 | tee -a ${FILE_LAST_LOG}

   echo " " 2>&1 | tee -a ${FILE_LAST_LOG}
done


### find old files and delete
print_basename "Searching for old folder(s) started..." 2>&1 | tee -a ${FILE_LAST_LOG}
COUNT=$(find ${BACKUP_PATH%/*} -maxdepth 1 -type d -mtime +${BACKUP_DAYS} |wc -l)
(
if [ "${COUNT}" != 0 ]; then
   print_basename "\"${COUNT}\" old folder(s) will be deleted..."
   find ${BACKUP_PATH%/*} -maxdepth 1 -type d -mtime +${BACKUP_DAYS} -exec rm -rf "{}" \;
   #print_basename "Deleting empty folders..."
   #find /var/backup/container/ -empty -type d -delete
   echo " "
else
   print_basename "No old folder(s) were found."
   echo " "
fi
) 2>&1 | tee -a ${FILE_LAST_LOG}


### show backups
# show last backup of docker container volume
(
print_basename "======= Schow last backup of docker container volume(s) ======="
tree -iFrh ${BACKUP_PATH} | grep -v /$ | sed '/director/d'
echo " "
)  2>&1 | tee -a ${FILE_LAST_LOG}

# show all backup Directories
(
print_basename "======= Schow all backup directories  ======="
tree -i -d -L 1 ${BACKUP_PATH%/*} | sed '/director/d'
) 2>&1 | tee -a ${FILE_LAST_LOG}


### Send status e-mail
if [ ${MAIL_STATUS} = 'Y' ]; then
   sendmail STATUS
fi

