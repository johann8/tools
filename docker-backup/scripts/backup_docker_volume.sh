#!/bin/bash
#
#set -x

# Usage:
# No script argument - make volume backup of all docker containers
#
# Script argument - make volume backup entered docker container
# You must enter the Container ID
# Container IDs must be separated from each other with a space character

#
### === Set Variables ===
#

# CUSTOM vars - define colors
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"; xxxf="${esc}[1;32m"
boldon="${esc}[1m"; boldoff="${esc}[22m"
reset="${esc}[0m"

# CUSTOM - script
SCRIPT_NAME="backupDCV.sh"                      # DCV - docker container volume
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.1.3"

# CUSTOM - vars
TIMESTAMP=$(date +%F_%H-%M)
TIMESTAMP1=$(date "+%Y-%m-%d %H:%M:%S")
BACKUP_PATH=/tmp/${TIMESTAMP}
FILE_EXTENSION=tar.zstd                         # Valid: tzst | tar.zst | tar.zstd | tgz | tar.gz | tbz2 | tar.bz2
IMAGE_NAME="johann8/dcbackup"
TAR_OPTIONS="--exclude=/opt/bacula/archive/*"   # Bacula storage folder

#
### === Functions ===
#

print_basename() {
   echo -e "${pinkf}${BASENAME}:${reset} $1"
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

# check if docker image loaded and up to date
echo -e "\n"
docker images -a |grep ${IMAGE_NAME}
if [ $? == 0 ]; then
   print_basename "There is a docker image ${cyanf}\"${IMAGE_NAME}\"${reset}"

   # check if image is recent
   RUNNING_IMAGE="$(docker inspect --format "{{.Id}}" --type image "${IMAGE_NAME}")"
   docker pull ${IMAGE_NAME} 2> /dev/null
   LATEST_IMAGE="$(docker inspect --format "{{.Id}}" --type image "${IMAGE_NAME}")"

   if ! [ ${RUNNING_IMAGE} = ${LATEST_IMAGE} ]; then
      print_basename "There is a more recent docker image ${cyanf}\"${IMAGE_NAME}\"${reset}"
      print_basename "Removing old image ${cyanf}\"${IMAGE_NAME}\"${reset}... "
      docker rmi ${IMAGE_NAME}
      print_basename "Downloading image ${cyanf}\"${IMAGE_NAME}\"${reset}... "
      echo ""
      docker pull ${IMAGE_NAME}
   else
      echo ""
      print_basename "The docker image ${cyanf}\"${IMAGE_NAME}\"${reset} is up to date."
   fi
else
   print_basename "There is no docker image ${cyanf}\"${IMAGE_NAME}\"${reset}"
   print_basename "Downloading image ${cyanf}\"${IMAGE_NAME}\"${reset}... "
   docker pull ${IMAGE_NAME}
fi

echo ""
print_basename "${greenf}+------------------------------------------------------------------------------------------+${reset}"
print_basename "${greenf}|${reset} Start docker volume backup on host: ${cyanf}\"$(hostname -f)\"${reset} at ${cyanf}\"${TIMESTAMP1}\"${reset} ${greenf}|${reset}"
print_basename "${greenf}+------------------------------------------------------------------------------------------+${reset}\n"

for i in `docker inspect --format='{{.Name}}' ${CONTAINER_ID} | cut -f2 -d\/`; do
   echo ""
   CONTAINER_NAME=$i
   mkdir -p ${BACKUP_PATH}/${CONTAINER_NAME}
   echo -n "${cyanf}\"${CONTAINER_NAME}\"${reset} - "
   docker run --rm --userns=host \
   --volumes-from ${CONTAINER_NAME} \
   -v ${BACKUP_PATH}:/backup \
   -e TAR_OPTS="${TAR_OPTIONS}" \
   johann8/dcbackup:latest \
   backup "${CONTAINER_NAME}/${CONTAINER_NAME}-volume.backup.${FILE_EXTENSION}"
   echo ""
done

