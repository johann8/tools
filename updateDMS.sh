#!/bin/bash

# Abort on all errors, set -x
set -o errexit
#set -x

#
### === Set Variables ===
#
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
BASENAME="${0##*/}"
SCRIPT_VERSION="0.1.1"
WORKING_DIR=$(pwd)

# CUSTOM vars - define colors
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"
blackf="${esc}[30m"; whitef="${esc}[37m"; xxxf="${esc}[1;32m";
boldon="${esc}[1m"; boldoff="${esc}[22m";
reset="${esc}[0m"

#
### === Functions ===
#

# Function print script basename
print_basename() {
   echo -e "${pinkf}${BASENAME}:${reset} $1"
}

# Function print kopf
print_kopf() {
   print_basename "${greenf}=======================================================${reset}"
}

# Function print foot
print_foot() {
   print_basename "${greenf}-----------------------------------------------------${reset}"
}

print_kopf_short() {
   print_basename "${greenf}=====================================================${reset}"
}

#
### ============= Main script ============
#

print_basename "Script version is: ${cyanf}\"${SCRIPT_VERSION}\"${reset}"
print_basename "Docker microservice name: ${cyanf}\"${WORKING_DIR##*/}\"${reset}"
print_basename "${greenf}+-----------------------------------------------------------------------------------+${reset}"
print_basename "${greenf}|${reset} Start update on host: ${cyanf}\"$(hostname -f)\"${reset} at ${cyanf}\"${TIMESTAMP}\"${reset} ${greenf}|${reset}"
print_basename "${greenf}+-----------------------------------------------------------------------------------+${reset}\n"

# Put all running containers in array
ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))

print_kopf_short
print_basename "  There is/are \"${cyanf}${#ar_lc[*]}${reset}\" docker container(s):${cyanf}  \"$(echo ${ar_lc[*]})\""${reset}
print_kopf_short

for i in ${ar_lc[*]}; do
   STATUS_CONTAINER=$(docker inspect -f '{{.State.Status}}' ${i})
   echo -n -e "${pinkf}${BASENAME}:${reset} "; printf "%-20s %-27s %1s %-5s\n" " Docker Container:" "${cyanf} $i${reset}" "-" "${bluef}${STATUS_CONTAINER}${reset}"
done
print_foot

# Check if there is/are an update of docker image; pull docker image
for i in ${ar_lc[*]}; do
   # Get hash of the running container (both same result)
   IMAGE_HASH=$(docker inspect ${i} --format '{{ index .Config.Labels "com.docker.compose.image"}}')
   RUNNING_IMAGE="$(docker inspect --format "{{.Image}}" --type container ${i})"

   # Get docker image and tag
   CONTAINER_IMAGE="$(docker inspect --format "{{.Config.Image}}" --type container ${i})"

   echo ""
#   print_kopf_long
#   print_basename "  Updating Docker Image ${cyanf}\"${i}\"${reset} am ${TIMESTAMP}"
#   print_kopf_long
   docker pull ${CONTAINER_IMAGE} 2> /dev/null
   LATEST_IMAGE="$(docker inspect --format "{{.Id}}" --type image "${CONTAINER_IMAGE}")"

   print_basename "${greenf}Container name:${cyanf} \"${i}\"${reset}"
   print_basename "${greenf}Container ${cyanf}\"${i}\" ${greenf}- running image hash:${reset} ${bluef}${RUNNING_IMAGE}${reset}"
   print_basename "${greenf}Container ${cyanf}\"${i}\" ${greenf}- pulled image hash:${reset}  ${redf}${LATEST_IMAGE}${reset}"

   # Update / Exit
   if ! [ ${RUNNING_IMAGE} = ${LATEST_IMAGE} ]; then
      print_basename "${redf}  There is an update of docker image: ${cyanf}\"${i}\"${reset}"
      RES=true
   else
      print_basename "${redf}  There is no update of docker image: ${cyanf}\"${i}\"${reset}"
   fi
done

# Restart and delete microservices
if [[ "${RES}" = true ]]; then
   echo ""
   print_kopf
   print_basename "${greenf}  There is/are an update of docker image(s)!${reset}"
   print_kopf
   print_basename "${greenf}  Microservice is restarting... ${reset}"
   docker-compose down && docker-compose up -d

   print_basename "${greenf} Deleting dangling images... ${reset}"
   docker rmi $(docker images -f "dangling=true" -q --no-trunc)
else
   echo ""
   print_kopf
   print_basename "${redf}  There is/are no update of docker image(s):${cyanf}  \"$(echo ${ar_lc[*]})\""${reset}
   print_kopf
fi

