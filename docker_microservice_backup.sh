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
SCRIPT_VERSION="0.1.1"
_HOST=$(echo $(hostname) | cut -d"." -f1)

# CUSTOM vars - define colors
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"; xxxf="${esc}[1;32m"
boldon="${esc}[1m"; boldoff="${esc}[22m"
reset="${esc}[0m"

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

# CUSTOM - Backup files
BACKUPDIR="/var/backup/${_HOST}/compose_projects"
FILE_BACKUP=backup-$(echo ${TIMESTAMP}).tzst
FILE_DELETE='*.tzst'
DAYS_NUMBER=30

#
### === Functions ===
#

# Function print script basename
print_basename() {
   echo -e -n "${pinkf}${BASENAME}:${reset} $1"
}

#
### ============= Main script ============
#

#echo -e "|  ${TIMESTAMP1} Start Backup for Docker Compose Projects!  |"

print_basename "Script version is: ${cyanf}\"${SCRIPT_VERSION}\"${reset}"
print_basename "${greenf}+-----------------------------------------------------------------------------------+${reset}"
print_basename "${greenf}|${reset} Start backup on host: ${cyanf}\"$(hostname -f)\"${reset} at ${cyanf}\"${TIMESTAMP}\"${reset} ${greenf}|${reset}"
print_basename "${greenf}+-----------------------------------------------------------------------------------+${reset}\n"

# check path FILE_BACKUP
if [ ! -d ${BACKUPDIR} ]; then
   print_basename "Creating backup dir..."
   mkdir -p ${BACKUPDIR}
fi

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
print_basename "\n==========================================="
print_basename " There are \"${#COMPOSE_PROJECTS_NAME[*]}\" Docker Composer Project(s): ${COMPOSE_PROJECTS_NAME[*]}"
print_basename -e "===========================================\n"

# Backup all Docker Composer Project(s)
for i in ${COMPOSE_PROJECTS_PATH}; do
    cd ${i}

    print_basename "============ ${i##*/} ============"
    print_basename "Project working dir: ${i}"

    #
    ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))
    print_basename "There are \"${#ar_lc[*]}\" container(s) in this project: ${ar_lc[*]}"

    # Stop all containers, make backup and start all containers
    print_basename "\n${TIMESTAMP2} Docker Compose Project \"${i##*/}\" is backed up... "
    print_basename "All docker containers are stopped... "
    ${DOCKER_COMPOSE_COMMAND} down

    print_basename "\nDoing compose project backup... "
    ${TAR_COMMAND} -I 'zstd -15 -T0' -cvf ${BACKUPDIR}/${i##*/}-${FILE_BACKUP} ${TAR_OPTIONS} ${TAR_EXCLUDE} . > /dev/null 2>&1

    print_basename "All docker containers are started... \n"
    ${DOCKER_COMPOSE_COMMAND} up -d
    #echo "[ DONE ]"

    print_basename "\n${TIMESTAMP2} Docker Compose Project \"${i##*/}\" is successfully backed up\n\n"

#    #
#    for n in ${ar_lc[*]}; do
#       IMAGE_NAME=${n}
#       CONTAINER_ID=$(docker ps -qf name="${IMAGE_NAME}")
#       echo "Image name: ${IMAGE_NAME}"
#       echo "ContainerID: ${CONTAINER_ID}"
#       echo -e "Backup of Compose Project: ${IMAGE_NAME}\n"
#    done
done

print_basename "+-----------------------------------------------------------------+"
print_basename "|   ${TIMESTAMP1} Backup for Compose Projects completed!    |"
print_basename "+-----------------------------------------------------------------+"

# echo -e "\n$TIMESTAMP Backup for Compose Projects completed\n"

# Extract archive
# tar -xvf /tmp/etc.tzst -I 'zstd'

# List files in archive
#tar -tvf /tmp/etc.tzst -I 'zstd'

# Example
#tar -tvf /var/backup/oraclel8/compose_projects/bacularis-backup-20230606_144857.tzst -I 'zstd'