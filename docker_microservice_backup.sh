#!/bin/bash

# Abort on all errors, set -x
set -o errexit
#set -x

#
### === Set Variables ===
#
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"; xxxf="${esc}[1;32m"
boldon="${esc}[1m"; boldoff="${esc}[22m"
reset="${esc}[0m"

# CUSTOM - script
SCRIPT_NAME='backup_docker_container'
_HOST=$(echo $(hostname) | cut -d"." -f1)
basename="${0##*/}"

# Print script name
print_basename() { echo "${pinkf}${basename}:${reset} $1"; }
SCRIPT_VERSION="0.1.0"

# CUSTOM - Variables
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TIMESTAMP1=$(date +'%Y-%m-%d %H:%M:%S')
TIMESTAMP2=$(date +'%H:%M:%S')
ZSTD_COMMAND=$(command -v zstd)
DOCKER_COMPOSE_COMMAND=$(command -v docker-compose)
TAR_COMMAND=$(command -v tar)
TAR_OPTIONS="--one-file-system"
TAR_EXCLUDE="--exclude=data/bacula/data/director/archive/*"

# CUSTOM - container and compose project
ALLCONTAINER=$(docker ps --format '{{.Names}}')
COMPOSE_PROJECTS_PATH=$(for i in $ALLCONTAINER; do docker inspect --format '{{ index .Config.Labels "com.docker.compose.project.working_dir"}}' $i; done | sort -u)
COMPOSE_PROJECTS_NAME=($(docker inspect $(docker ps -q) --format '{{ index .Config.Labels "com.docker.compose.project"}}' | uniq))

# CUSTOM - Backup-Files.
BACKUPDIR="/var/backup/${_HOST}/compose_projects"
FILE_BACKUP=backup-$(echo ${TIMESTAMP}).tzst
FILE_DELETE='*.tzst'
DAYS_NUMBER=30

#
### ============= Main script ============
#

echo -e "+-----------------------------------------------------------------+"
echo -e "|  ${TIMESTAMP1} Start Backup for Docker Compose Projects!  |"
echo -e "+-----------------------------------------------------------------+\n"

# check path FILE_BACKUP
if [ ! -d ${BACKUPDIR} ]; then
   echo -n "Creating  "
   mkdir -p ${BACKUPDIR}
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${ZSTD_COMMAND}" ]; then
   echo -e "Check if command '${ZSTD_COMMAND}' was found..............[FAILED]"
   exit 11
else
   echo -e "Check if command '${ZSTD_COMMAND}' was found.............[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${DOCKER_COMPOSE_COMMAND}" ]; then
   echo -e "Check if command '${DOCKER_COMPOSE_COMMAND}' was found...[FAILED]"
   exit 12
else
   echo -e "Check if command '${DOCKER_COMPOSE_COMMAND}' was found...[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${TAR_COMMAND}" ]; then
   echo -e "Check if command '${TAR_COMMAND}' was found..............[FAILED]"
   exit 13
else
   echo -e "Check if command '${TAR_COMMAND}' was found..............[  OK  ]"
fi

### Run backup
#ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))
echo -e "\n==========================================="
echo " There are \"${#COMPOSE_PROJECTS_NAME[*]}\" Docker Composer Project(s): ${COMPOSE_PROJECTS_NAME[*]}"
echo -e "===========================================\n"

# Backup all Docker Composer Project(s)
for i in ${COMPOSE_PROJECTS_PATH}; do
    cd ${i}

    echo "============ ${i##*/} ============"
    echo "Project working dir: ${i}"

    #
    ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))
    echo "There are \"${#ar_lc[*]}\" container(s) in this project: ${ar_lc[*]}"

    # Stop all containers, make backup and start all containers
    echo -e "\n${TIMESTAMP2} Docker Compose Project \"${i##*/}\" is backed up... "
    echo -e "All docker containers are stopped... "
    ${DOCKER_COMPOSE_COMMAND} down
    #echo "[ DONE ]"

    echo -e "\nDoing compose project backup... "
    ${TAR_COMMAND} -I 'zstd -15 -T0' -cvf ${BACKUPDIR}/${i##*/}-${FILE_BACKUP} ${TAR_OPTIONS} ${TAR_EXCLUDE} . > /dev/null 2>&1

    echo -e "All docker containers are started... \n"
    ${DOCKER_COMPOSE_COMMAND} up -d
    #echo "[ DONE ]"

    echo -e "\n${TIMESTAMP2} Docker Compose Project \"${i##*/}\" is successfully backed up\n\n"

#    #
#    for n in ${ar_lc[*]}; do
#       IMAGE_NAME=${n}
#       CONTAINER_ID=$(docker ps -qf name="${IMAGE_NAME}")
#       echo "Image name: ${IMAGE_NAME}"
#       echo "ContainerID: ${CONTAINER_ID}"
#       echo -e "Backup of Compose Project: ${IMAGE_NAME}\n"
#    done
done

echo -e "+-----------------------------------------------------------------+"
echo -e "|   ${TIMESTAMP1} Backup for Compose Projects completed!    |"
echo -e "+-----------------------------------------------------------------+"

# echo -e "\n$TIMESTAMP Backup for Compose Projects completed\n"

# Extract archive
# tar -xvf /tmp/etc.tzst -I 'zstd'

# List files in archive
#tar -tvf /tmp/etc.tzst -I 'zstd'

# Example
#tar -tvf /var/backup/oraclel8/compose_projects/bacularis-backup-20230606_144857.tzst -I 'zstd'
