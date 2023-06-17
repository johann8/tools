#!/bin/bash

# Abort on all errors, set -x
set -o errexit
#set -x

#
### === Set Variables ===
#
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"
blackf="${esc}[30m"; whitef="${esc}[37m"; xxxf="${esc}[1;32m";
boldon="${esc}[1m"; boldoff="${esc}[22m";
reset="${esc}[0m"

#
### === Functions ===
#
# Function print kopf
print_kopf() {
   echo "${greenf}======================================================${reset}"
}

# Function print foot
print_foot() {
   echo "${greenf}------------------------------------------------------${reset}"
   #echo ""
}

print_kopf_long() {
   echo ${greenf}=================================================================${reset}
}


print_kopf_short() {
   echo "${greenf}==============================================${reset}"
}

#
### ============= Main script ============
#

# Put all running containers in array
ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))

print_kopf
echo "There are/is \"${cyanf}${#ar_lc[*]}${reset}\" docker container(s):${cyanf}  \"$(echo ${ar_lc[*]})\""${reset}
print_kopf
for i in ${ar_lc[*]}; do
   STATUS_CONTAINER=$(docker inspect -f '{{.State.Status}}' ${i})
   printf "%-20s %-27s %1s %-5s\n" "Docker Container:" "${cyanf} $i${reset}" "-" "${bluef}${STATUS_CONTAINER}${reset}"
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
   print_kopf_long
   echo "  Updating Docker Image ${cyanf}\"${i}\"${reset} am ${TIMESTAMP}"
   print_kopf_long
   docker pull ${CONTAINER_IMAGE} 2> /dev/null
   LATEST_IMAGE="$(docker inspect --format "{{.Id}}" --type image "${CONTAINER_IMAGE}")"

   echo "${greenf}Container name:${cyanf} ${i}${reset}"
   echo "${greenf}Container ${cyanf}${i} ${greenf}- running image hash:${reset} ${bluef}${RUNNING_IMAGE}${reset}"
   echo "${greenf}Container ${cyanf}${i} ${greenf}- pulled image hash:${reset}  ${redf}${LATEST_IMAGE}${reset}"

   # Update / Exit
   if ! [ ${RUNNING_IMAGE} = ${LATEST_IMAGE} ]; then
      echo "${redf}There is an update of docker image: ${cyanf}\"${i}\"${reset}"
      RES=true
   else
      echo "${redf}There is no update of docker image: ${cyanf}\"${i}\"${reset}"
   fi
done

# Restart and delete microservices
if [[ "${RES}" = true ]]; then
   echo ""
   print_kopf_short
   echo "${greenf}  There is/are an update of docker image(s)!${reset}"
   print_kopf_short
   echo "${greenf}  Microservice is restarting... ${reset}"
   docker-compose down && docker-compose up -d

   echo "${greenf} Deleting dangling images... ${reset}"
   docker rmi $(docker images -f "dangling=true" -q --no-trunc)
else
   echo ""
   print_kopf_short
   echo "${redf}  There is/are no update of docker image(s):${cyanf}  \"$(echo ${ar_lc[*]})\""${reset}
   print_kopf_short
fi
