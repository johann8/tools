#!/bin/bash

# Abort on all errors, set -x
set -o errexit
#set -x

#
### === Set Variables ===
#

# CUSTOM - script
SCRIPT_NAME='backup_docker_container'
BASENAME="${0##*/}"
SCRIPT_VERSION="0.1.2"
_HOST=$(echo $(hostname) | cut -d"." -f1)

# CUSTOM vars - define colors
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"; xxxf="${esc}[1;32m"
boldon="${esc}[1m"; boldoff="${esc}[22m"
reset="${esc}[0m"

# CUSTOM - Variables
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TIMESTAMP1=$(date +'%Y-%m-%d %H:%M:%S')
TIMESTAMP3=$(date +'%Y-%m-%d')
ZSTD_COMMAND=$(command -v zstd)
DOCKER_COMPOSE_COMMAND=$(command -v docker-compose)
TAR_COMMAND=$(command -v tar)
TAR_OPTIONS="--one-file-system"
TAR_EXCLUDE="--exclude=data/bacula/data/director/archive/*"

# CUSTOM - container and compose project
ALLCONTAINER=$(docker ps --format '{{.Names}}')
COMPOSE_PROJECTS_PATH=$(for i in $ALLCONTAINER; do docker inspect --format '{{ index .Config.Labels "com.docker.compose.project.working_dir"}}' $i; done | sort -u)
COMPOSE_PROJECTS_NAME=($(docker inspect $(docker ps -q) --format '{{ index .Config.Labels "com.docker.compose.project"}}' | uniq))

# CUSTOM - Backup files
STORAGE="/var/backup/${_HOST}/compose_projects"
BACKUPDIR="${STORAGE}/${TIMESTAMP3}"
FILE_BACKUP=backup-$(echo ${TIMESTAMP}).tzst
FILE_DELETE='*.tzst'

# CUSTOM - change me
DAYS_NUMBER=5           # Number of stored backups
NUMBERS_ON=true         # True: All Characters; False: Only letters
SERVICE_NAME="monit"    # Monitoring service name

#
### === Functions ===
#

# Function print script basename
print_basename() {
   echo -e "${pinkf}${BASENAME}:${reset} $1"
}

#
### ============= Main script ============
#

#echo -e "|  ${TIMESTAMP1} Start Backup for Docker Compose Projects!  |"

print_basename "Script version is: ${cyanf}\"${SCRIPT_VERSION}\"${reset}"
print_basename "${greenf}+----------------------------------------------------------------------------+${reset}"
print_basename "${greenf}|${reset} Start backup on host: ${cyanf}\"$(hostname -f)\"${reset} at ${cyanf}\"${TIMESTAMP1}\"${reset} ${greenf}|${reset}"
print_basename "${greenf}+----------------------------------------------------------------------------+${reset}"
echo -e ""

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${ZSTD_COMMAND}" ]; then
   print_basename "Check if command '${ZSTD_COMMAND}' was found..............[FAILED]"
   exit 11
else
   print_basename "Check if command '${ZSTD_COMMAND}' was found.............[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${DOCKER_COMPOSE_COMMAND}" ]; then
   print_basename "Check if command '${DOCKER_COMPOSE_COMMAND}' was found...[FAILED]"
   exit 12
else
   print_basename "Check if command '${DOCKER_COMPOSE_COMMAND}' was found...[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${TAR_COMMAND}" ]; then
   print_basename "Check if command '${TAR_COMMAND}' was found..............[FAILED]"
   exit 13
else
   print_basename "Check if command '${TAR_COMMAND}' was found..............[  OK  ]"
fi

### Run backup
#ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))
echo ""
print_basename "${greenf}============================================${reset}"
print_basename " There are ${cyanf}\"${#COMPOSE_PROJECTS_NAME[*]}\"${reset} Docker Composer Project(s): ${cyanf}\"${COMPOSE_PROJECTS_NAME[*]}\"${reset}"
print_basename "${greenf}============================================${reset}"
echo -e "\n"

# check if monitoring is running
if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
  # check if monitoring is running
  print_basename "Monitoring service ${cyanf}\"${SERVICE_NAME}\"${reset} is running."
  print_basename "Stopping monitoring service ${cyanf}\"${SERVICE_NAME}\"${reset}... "

  systemctl stop ${SERVICE_NAME}.service
  RES_SERVICE=1
else
  print_basename "Monitoring service ${SERVICE_NAME} is not running."
fi
echo -e "\n\n"

# Backup all Docker Composer Project(s)
for i in ${COMPOSE_PROJECTS_PATH}; do
    cd ${i}

    print_basename "${greenf}============= ${cyanf}\"MS: ${i##*/}\"${reset} ${greenf}=============${reset}"
    print_basename " Microservice working dir: ${cyanf}\"${i}\"${reset}"

    # check path BACKUPDIR
    if [ ! -d ${BACKUPDIR} ]; then
       print_basename "Creating backup dir: ${cyanf}\"${BACKUPDIR}\"${reset}..."
       mkdir -p ${BACKUPDIR}
    fi

    # list all docker container
    ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))
    print_basename "There is/are ${cyanf}\"${#ar_lc[*]}\"${reset} container(s) in this project: ${cyanf}\"${ar_lc[*]}\"${reset}"

    # Stop all containers, make backup and start all containers
    echo ""
    TIMESTAMP2=
    TIMESTAMP2=$(date +'%H:%M:%S')
    print_basename "${cyanf}${TIMESTAMP2}${reset} Docker microservice(s) ${cyanf}\"${i##*/}\"${reset} is/are backed up... "
    print_basename "All docker container(s) is/are stopped... "
    ${DOCKER_COMPOSE_COMMAND} down

    echo ""
    print_basename "Running docker microservices backup... "
    ${TAR_COMMAND} -I 'zstd -15 -T0' -cvf ${BACKUPDIR}/${i##*/}-${FILE_BACKUP} ${TAR_OPTIONS} ${TAR_EXCLUDE} . > /dev/null 2>&1
    #print_basename "*** RUN TAR ***"

    print_basename "All docker container(s) is/are started... "
    echo ""
    ${DOCKER_COMPOSE_COMMAND} up -d
    TIMESTAMP2=
    TIMESTAMP2=$(date +'%H:%M:%S')
    print_basename "${cyanf}${TIMESTAMP2}${reset} Docker Compose Project \"${i##*/}\" is successfully backed up!"
    echo -e "\n\n"
#
#    for n in ${ar_lc[*]}; do
#       IMAGE_NAME=${n}
#       CONTAINER_ID=$(docker ps -qf name="${IMAGE_NAME}")
#       echo "Image name: ${IMAGE_NAME}"
#       echo "ContainerID: ${CONTAINER_ID}"
#       echo -e "Backup of Compose Project: ${IMAGE_NAME}\n"
#    done
done

# Starting monitoring service
if [[ ${RES_SERVICE} == 1 ]]; then
  print_basename "Starting monitoring service ${cyanf}\"${SERVICE_NAME}\"${reset}... "
  systemctl start ${SERVICE_NAME}.service
fi

#
### === Delete old files ===
#

# List all folders in an array
if [[ "${NUMBERS_ON}" = false ]]; then
    # Only letters
    ARRAY=($(ls ${STORAGE} | grep -v '[^A-Za-z]'))
else
    # All Characters
    ARRAY=($(ls ${STORAGE}))
fi

# Delete old backups
if [ -d ${STORAGE} ]; then
   cd ${STORAGE}
   print_basename "Deleting old backups... "
   print_basename "Storage path: ${cyanf}\"$(pwd)\"${reset}"

   # Number of existing backup files
   COUNT_FOLDERS=$(echo ${#ARRAY[@]})

   if [ ${COUNT_FOLDERS} -le ${DAYS_NUMBER} ]; then
      print_basename "SKIP: There are too few backups to delete: ${cyanf}\"${COUNT_FOLDERS}\"${reset}"
   else
      COUNT_FOLDERS_TO_DELETE=$(ls -t | tail -n +$(expr ${DAYS_NUMBER} + 1) | wc -l);
      print_basename "${cyanf}\"${COUNT_FOLDERS_TO_DELETE}\"${reset} old backup(s) to delete... "
      # Only for test
      #(ls -t | tail -n +$(expr ${DAYS_NUMBER} + 1)) | wc -l > /dev/null 2>&1
      (ls -t | tail -n +$(expr ${DAYS_NUMBER} + 1)) | xargs rm -rf
      RES1=$?

      # Check result
      if [ "$RES1" = "0" ]; then
         print_basename "${cyanf}\"${COUNT_FOLDERS_TO_DELETE}\"${reset} old backup(s) was/were deleted!"
         #print_basename "${greenf}--------------------------\"${reset}"
      else
         print_basename "Error: Old backups could not be deleted!"
         exit 1
      fi
   fi
else
   print_basename "Error: The directory ${cyanf}\"${STORAGE}\" does not exist."
   exit 1
fi

#
### === Show backups of microservice(s) ===
#
echo -e "\n\n"
print_basename "${greenf}======= ${cyanf}Show backups of microservice(s) ${greenf}=======${reset}"
tree -iFrh ${STORAGE}

#
echo -e "\n\n"
print_basename "${greenf}+-----------------------------------------------------------------+${reset}"
print_basename "${greenf}|${reset}   ${TIMESTAMP1} Backup for Compose Projects completed!    ${greenf}|${reset}"
print_basename "${greenf}+-----------------------------------------------------------------+${reset}"

# echo -e "\n$TIMESTAMP Backup for Compose Projects completed\n"

# Extract archive
# tar -xvf /tmp/etc.tzst -I 'zstd'

# List files in archive
#tar -tvf /tmp/etc.tzst -I 'zstd'

# Example
#tar -tvf /var/backup/oraclel8/compose_projects/bacularis-backup-20230606_144857.tzst -I 'zstd'
