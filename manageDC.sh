#!/bin/bash
#
# Debug enable
#set -x
#
set -o errexit


#
### define colors
#
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"; xxxf="${esc}[1;32m"
boldon="${esc}[1m"; boldoff="${esc}[22m"
reset="${esc}[0m"

#
### === Set variables ===
#
basename="${0##*/}"
# Print script name
print_basename() { echo "${pinkf}${basename}:${reset} $1"; }
SCRIPT_VERSION="0.4.2"                  # Set script version
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")  # time stamp

#
### === Shared DB between containers ===
#

### *** Change me ***
DB_CONTAINER_NAME=mariadb               # The name of MySQL / MariaDB container
DB_NETWORK=mysqlNet                     # The name of network of MySQL / MariaDB container
HYPHEN_ON=false                         # Docker microservice name may contain only: letters and numbers; Letters, numper and hyphen: false
SCRIPT_ARG=$(for arg in "$*"; do echo "$arg"; done)

#
### === Set Pathes ===
#
# docker-compose
DOCKER_COMPOSE_PATH=""
DOCKER_COMPOSE_PATH="${DOCKER_COMPOSE_PATH:-/usr/local/bin}"

# Check if at least one container is running
NUMBER_RUNNING_CONTAINER=$(docker ps -q |wc -l)

# Print script version
print_basename "Script version is: ${cyanf}\"${SCRIPT_VERSION}\"${reset}"

# Check if at least one container is running. If not, then ask to start
if [[ ${NUMBER_RUNNING_CONTAINER} -ne 0 ]]; then
   RES=0
   print_basename "The number of running container(s): ${cyanf}\"${NUMBER_RUNNING_CONTAINER}\"${reset}"

   #  Check if at least one microservice is running
   NUMBER_RUNNING_MICROSERVICE=$(docker inspect $(docker ps -q) --format '{{ index .Config.Labels "com.docker.compose.project.working_dir"}}' |uniq |wc -l)
   print_basename "The number of running docker microservice(s): ${cyanf}\"$(echo ${NUMBER_RUNNING_MICROSERVICE})\"${reset}"
else
   RES=1
   print_basename "The number of running container(s): ${cyanf}\"${NUMBER_RUNNING_CONTAINER}\"${reset}"

   # Search after microservice(s)
   ar_shc=($(find /opt -maxdepth 3 -name docker-compose.yml | sed 's+/[^/]*$++' | sed 's+^.*/++' | grep -v '[^A-Za-z0-9]'))

   print_basename "The script has found following docker microservice(s): ${cyanf}\"$(echo ${ar_shc[@]})\"${reset}"
   print_basename "For the script to run correctly, at least one container must be running."

   _RES=
   until [ "$_RES" = "1" ]; do
      print_basename "Would you like to start a docker microservice? [y/n]: "; read _ANSWER
      case $_ANSWER in
      y) echo -e ""; print_basename "Please enter the name of docker microservice: "; read _NAME
         # Replace all spaces with separators
         _STRING=$(echo ${ar_shc[@]} | tr -s ' ' '|')

         # Check if entered name exists
         if [[ ${_NAME} =~ (${_STRING}) ]]; then
            print_basename "Entered name: ${cyanf}\"${_NAME}\"${reset}"

            # determine working dir
            W_DIR=$(find /opt -maxdepth 3 -name docker-compose.yml | sed 's+/[^/]*$++' |grep ${_NAME})
            cd ${W_DIR} \
            && \
            print_basename "Launch docker microservice: ${cyanf}\"${_NAME}\"${reset}" \
            # launch microservice
            ${DOCKER_COMPOSE_PATH}/docker-compose up -d
            _RES=1
            exit 0
         else
            echo "The name \"${_NAME}\" does not exist. Try once again";
         fi
      ;;
   n) print_basename "You do not want to start a docker microservice."; _ans=1; exit 0
      ;;
   *) print_basename "Please enter \"y\" or \"n\""
      ;;
   esac
   done
fi


# container working dir
#DEFAULT_CONTAINER_SAVE_PATH="/opt"
if [[ -f ${DOCKER_COMPOSE_PATH}/docker-compose ]]
then
    #FIND_CONTAINER_SAVE_PATH=$(find ${DEFAULT_CONTAINER_SAVE_PATH} -maxdepth 2 -name docker-compose.yml |uniq |head -1 |sed 's+/[^/]*$++' |sed 's+/[^/]*$++')
    FIND_CONTAINER_SAVE_PATH=$(docker inspect $(docker ps -q) --format '{{ index .Config.Labels "com.docker.compose.project.working_dir"}}' |uniq |head -n 1 |sed 's+/[^/]*$++')    
    CONTAINER_SAVE_PATH=${FIND_CONTAINER_SAVE_PATH}
else
    print_basename "ERROR: Docker-Compose binary not found: \"${DOCKER_COMPOSE_PATH}/docker-compose\""
    exit 1
fi

# get all docker microservices and save in an array
if [[ "${HYPHEN_ON}" = true ]]
then
    # Docker microservice name may contain only: letters, numbers and hyphen
    ar=($(find ${CONTAINER_SAVE_PATH} -maxdepth 2 -name docker-compose.yml | sed 's+/[^/]*$++' | sed 's+^.*/++' | grep -v '[^A-Za-z0-9-]'))
else
    # Docker microservice name may contain only: only letters and numbers
    ar=($(find ${CONTAINER_SAVE_PATH} -maxdepth 2 -name docker-compose.yml | sed 's+/[^/]*$++' | sed 's+^.*/++' | grep -v '[^A-Za-z0-9]'))
fi

# get all working dirs of container in an array 
ar_pwd=($(docker inspect $(docker ps -q) --format '{{ index .Config.Labels "com.docker.compose.project.working_dir"}}' |uniq))
# echo ${ar_pwd[@]} 

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################
#
### define functions
#

# ======= Functions =========
# print error
error_exit() {
    if [[ ! -z $1 ]]; then
        print_basename "$1 - returned non-zero exit code: terminating"
    fi
    exit 1
}

# Function: print success
print_success() {
   if [[ $? -ne 0 ]]; then
      RES1=1
   else
      RES1=0
      print_basename "$1"
   fi
}

# Function: print error
print_error() {
   if [[ ${RES1} == 1 ]]; then
      error_exit "$1"
   fi
}

# Function print kopf
print_kopf() {
    #echo ""
    echo "${greenf}======================================================${reset}"
}

# Function print foot
print_foot() {
   echo "${greenf}------------------------------------------------------${reset}"
   echo ""
}

# Function print end
 print_end() {
   echo "${greenf}*************************************************************${reset}"
   echo ""
}

# Function docker container(dc) kopf
print_dc_update_kopf() {
   echo "${yellowf}===================================================${reset}"
}

# Function docker container(dc) foot
print_dc_update_foot() {
   echo "${yellowf}---------------------------------------------------${reset}"
}


# Print error message in red
f_error() {
   echo ${redf}$1${reset}
}

# Show script version
show_version() {
   # Print script version
   print_kopf
   print_basename "Script version is: ${cyanf}\"${SCRIPT_VERSION}\"${reset}"
   print_foot
}

# For yes/no questions
f_promtConfigYN() {
 ans=
 until [ "$ans" = "1" ]; do
    case $# in
    3) echo -n "$1 [$2]: "; read _answer
       if [[ ! "$_answer" = [y,n] ]]; then
          echo ""; f_error "***ERROR: Please enter \"y\" or \"n\"."; echo ""
       else
          cmd="$3=\"$_answer\""
          eval $cmd; ans=1
       fi
    ;;
    2) echo -n "$1: "; read _answer
       if [ -z "$_answer" ]; then
          echo ""; f_error "***ERROR: the input must not be empty."; echo ""
       else
          cmd="$2=\"$_answer\""
          eval $cmd; ans=1
       fi
    ;;
    esac
 done
}

# Function start docker container
start_dc() {
   # Check if the name of docker container is equal the name of database container
   if [[ ${DOCKER_MICROSERVICE_NAME} == ${DB_CONTAINER_NAME} ]]
   then
      print_basename "Check if database mariadb is shared"
      IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
      SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
      ar_db=
      ar_db=($(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml |uniq | awk -F'/' '{print $3}'))
      

      # Check if Shared DB exist
      if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
         print_basename "INFO: Shared DB exist!"
         print_basename "Docker microservices with shared DB are: ${cyanf}\"${ar_db[*]}\"${reset}"
         print_basename "Total array length is: ${#ar_db[@]}"
         print_basename "Inserting value \"${DB_CONTAINER_NAME}\" on first place in array..."
         index_insert=0
         value_ar=${DB_CONTAINER_NAME}
         ar_db=("${ar_db[@]:0:$index_insert}" "$value_ar" "${ar_db[@]:$index_insert}")
         # Declare var ar_db as global
         declare -p ar_db > /dev/null 2>&1
         print_basename "INFO: insert done!"
         print_basename "Total array length is: ${#ar_db[@]}"
         print_basename "Found the following microservices: ${cyanf}\"${ar_db[*]}\"${reset}"
         echo ""
         print_basename "To start docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}, other microservices must be started as well: ${cyanf}\"${ar_db[*]}\"${reset}"

         echo ""    
         f_promtConfigYN "Do you also want to start those microservices?" "y/n" "A_ANSWER"

         # Start all containers with shared MariaDB
         if [ "${A_ANSWER}" = "y" ]; then
            print_basename "The answer is: ${greenf}\"${A_ANSWER}\"${reset}"
            # loop for all docker containers and stop them
            for D_MICROSERVICE_NAME in ${ar_db[*]}; do
               print_basename "Docker microservice ${cyanf}\"${D_MICROSERVICE_NAME}\"${reset} is being started..."
               print_kopf
               cd ${CONTAINER_SAVE_PATH}/${D_MICROSERVICE_NAME}
               print_basename "RUN: ${COMMAND} up -d"
               ${COMMAND} up -d
               C_RES1=$?
               sleep 5
               print_basename "RUN: ${COMMAND} ps"
               ${COMMAND} ps

               # check result
               if [[ "${C_RES1}" = "0" ]]; then
                  # Print success message if RES1=0
                  print_success "Starting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
                  print_foot
                  echo ""
               else
                  # Print error message if RES1=1
                  print_error "Error starting docker microservice!"
                  #exit 0
               fi
            done
         else
            print_basename "The answer is: ${redf}\"${A_ANSWER}\"${reset} "
            print_basename "Starting of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is canceled!"
            exit 0
         fi
      else
         print_basename "INFO: Shared DB does not exist!"
         # start container
         print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being started..."
         print_kopf
         cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
         print_basename "RUN: ${COMMAND} up -d"
         ${COMMAND} up -d
         sleep 5
         print_basename "RUN: ${COMMAND} ps"
         ${COMMAND} ps
      fi
   else
      # start
      print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being started..."
      print_kopf
      cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
      print_basename "RUN: ${COMMAND} up -d"
      ${COMMAND} up -d
      sleep 5
      print_basename "RUN: ${COMMAND} ps"
      ${COMMAND} ps
   fi
}

# Function stop docker container
stop_dc() {
   # Check if the name of docker container is equal the name of database container
   if [[ ${DOCKER_MICROSERVICE_NAME} == ${DB_CONTAINER_NAME} ]]
   then
      print_basename "Check if database mariadb is shared"
      IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
      SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
      ar_db=
      ar_db=($(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml |uniq | awk -F'/' '{print $3}'))

      # Check if Shared DB exist
      if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
         print_basename "INFO: Shared DB exist!"
         print_basename "Docker microservices with shared DB are: ${cyanf}\"${ar_db[*]}\"${reset}"
         print_basename "Total array length is: ${#ar_db[@]}"
         print_basename "Inserting value \"${DB_CONTAINER_NAME}\" on last place in array..."
         value_ar=${DB_CONTAINER_NAME}
         ar_db+=("$value_ar")
         # Declare var ar_db as global
         declare -p ar_db  > /dev/null 2>&1
         print_basename "Total array length is: ${#ar_db[@]}"
         print_basename "Found the following microservices: ${cyanf}\"${ar_db[*]}\"${reset}"
         echo ""
         print_basename "To stop docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}, other microservices must be stopped as well: ${cyanf}\"${ar_db[*]}\"${reset}"
         #echo ""
         f_promtConfigYN "Do you also want to stop these microservices?" "y/n" "A_ANSWER"

         # Stop all containers with shared MariaDB
         if [ "${A_ANSWER}" = "y" ]; then
            print_basename "The answer is: ${greenf}\"${A_ANSWER}\"${reset}"
            # loop for all docker containers and stop them
            for D_MICROSERVICE_NAME in ${ar_db[*]}; do
               print_basename "Docker microservice ${cyanf}\"${D_MICROSERVICE_NAME}\"${reset} is being stoped..."
               print_kopf
               cd ${CONTAINER_SAVE_PATH}/${D_MICROSERVICE_NAME}
               print_basename "RUN: ${COMMAND} down"
               ${COMMAND} down
               C_RES1=$?
               sleep 5
               print_basename "RUN: ${COMMAND} ps"
               ${COMMAND} ps

               # check result
               if [[ "${C_RES1}" = "0" ]]; then
                  # Print success message if RES1=0
                  print_success "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
                  print_foot
                  echo ""
               else
                  # Print error message if RES1=1
                  print_error "Error stopping docker microservice!"
                  #exit 0
               fi
            done
         else
            print_basename "The answer is: ${redf}\"${A_ANSWER}\"${reset} "
            print_basename "Stopping of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is canceled!"
            exit 0
         fi
      else
         print_basename "INFO: Shared DB does not exist!"
         # stop container
         print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being stoped..."
         print_kopf
         cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
         print_basename "RUN: ${COMMAND} down"
         ${COMMAND} down
         sleep 5
         print_basename "RUN: ${COMMAND} ps"
         ${COMMAND} ps
      fi
   else
       # stop container
       print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being stoped..."
       print_kopf
       cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
       print_basename "RUN: ${COMMAND} down"
       ${COMMAND} down
       sleep 5
       print_basename "RUN: ${COMMAND} ps"
       ${COMMAND} ps
   fi
}

# Function used for: manage all docker container
start_dc_all() {
   # start container for Option: -a
   print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being started..."
   print_kopf
   cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
   print_basename "RUN: ${COMMAND} up -d"
   ${COMMAND} up -d
   print_basename "RUN: ${COMMAND} ps"
   ${COMMAND} ps
   print_foot
}

# Function used for: manage all docker container
stop_dc_all() {
   # stop container for Option: -a
   print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being stoped..."
   print_kopf
   cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
   print_basename "RUN: ${COMMAND} down"
   ${COMMAND} down
   print_basename "RUN: ${COMMAND} ps"
   ${COMMAND} ps
   print_foot
}

# Function status container: running | stoped 
status_dms() {
   # list all containers
   cd ${CONTAINER_SAVE_PATH}/$1/
   ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))
   #echo "----------------"
   #echo -e "${ar_lc[@]}\n"

   # check if array is empty or not
   if ! [ ${#ar_lc[@]} -eq 0 ]; then
      CONTAINER_NAME=$(echo ${ar_lc[0]})
      CONTAINER_RUNNING=1
   else
      CONTAINER_RUNNING=0
   fi

   # status container: running | exited |not running
   if [[ ${CONTAINER_RUNNING} == 1 ]]; then
      _STATUS_DMS=$(docker inspect -f '{{.State.Status}}' ${CONTAINER_NAME})
   else
      _STATUS_DMS="not running"
   fi
}

# Function: Update docker container
update_dc() {
   # list all containers
   cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}/
   ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))

   # check if array is empty or not
   if ! [ ${#ar_lc[@]} -eq 0 ]; then
      CONTAINER_NAME=$(echo ${ar_lc[0]})
      print_basename "Docker container name is: ${cyanf}\"${CONTAINER_NAME}\"${reset}"
      CONTAINER_RUNNING=1
   else
      CONTAINER_RUNNING=0
   fi

   echo ${greenf}=================================================================${reset}
   echo "  Start updating Docker Microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} on ${TIMESTAMP}"
   echo ${greenf}=================================================================${reset}
   echo "***"

   # Update microservice
   ar_lc=($(docker-compose ps |awk '{print $1}' |awk '(NR>1)'))
   print_basename "There are/is \"${cyanf}${#ar_lc[*]}${reset}\" docker container(s):${cyanf}  \"$(echo ${ar_lc[*]})\""${reset}

   print_dc_update_kopf
   for i in ${ar_lc[*]}; do
      STATUS_CONTAINER=$(docker inspect -f '{{.State.Status}}' ${i})
      printf "%-20s %-27s %1s %-5s\n" "Docker Container:" "${cyanf} $i${reset}" "-" "${bluef}${STATUS_CONTAINER}${reset}"
   done
   print_dc_update_foot

   for i in ${ar_lc[*]}; do
      # Get hash of the running container (both same result)
      IMAGE_HASH=$(docker inspect ${i} --format '{{ index .Config.Labels "com.docker.compose.image"}}')
      RUNNING_IMAGE="$(docker inspect --format "{{.Image}}" --type container ${i})"

      # Get docker image and tag
      CONTAINER_IMAGE="$(docker inspect --format "{{.Config.Image}}" --type container ${i})"

      echo ""
      print_dc_update_kopf
      echo "  Updating Docker Image ${cyanf}\"${i}\"${reset} on ${TIMESTAMP}"
      print_dc_update_kopf

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

   # Restart and delete container(s)
   if [[ "${RES}" = true ]]; then
      echo ""
      print_dc_update_kopf
      echo "${greenf}  There is/are an update of docker image(s)!${reset}"
      print_dc_update_kopf
      echo "${greenf}  Microservice is restarting... ${reset}"
      docker-compose down && docker-compose up -d
      RES=

      echo "${greenf} Deleting dangling images... ${reset}"
      docker rmi $(docker images -f "dangling=true" -q --no-trunc)
   else
      echo ""
      print_kopf
      echo "${redf}  There is/are no update of docker image(s):${cyanf}  \"$(echo ${ar_lc[*]})\""${reset}
      print_kopf
   fi
}

# Function: check if container is running
dc_status() {
   _DC_STATUS=$( docker ps -a -f name=${DOCKER_MICROSERVICE_NAME} | grep ${DOCKER_MICROSERVICE_NAME} 2> /dev/null )
   if [[ ! -z ${_DC_STATUS} ]]; then
      print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} has status: $( echo ${_DC_STATUS} | awk '{ print $7 }' )"
   else
      print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} has status: Down"
      break
   fi
}

# Function: Reorder bash array for start, if shared db exists
# Used for: manage all docker container
check_shared_db_start() {
   IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
   SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
   if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
      print_basename "INFO: Shared DB exist!"
      for val in ${!ar[@]}; do
         index=${val}
         value=${ar[$val]}
         #echo "index = ${val} , value = ${ar[$val]}"
         if [ "${value}"  = "${DB_CONTAINER_NAME}" ]; then
            index_ar=${index}
            print_basename "Array index of \"${DB_CONTAINER_NAME}\" is: ${index_ar}"
            print_basename "Total array length is: ${#ar[@]}"
            print_basename "Unset value: ${DB_CONTAINER_NAME}"
            unset ar[$index_ar] 
            print_basename "INFO: unset done!"
            print_basename "Total array length is: ${#ar[@]}"
            print_basename "Insert \"${DB_CONTAINER_NAME}\" on first place"
            index_insert=0
            value_ar=${DB_CONTAINER_NAME}
            ar=("${ar[@]:0:$index_insert}" "$value_ar" "${ar[@]:$index_insert}")
            print_basename "INFO: insert done!"
            print_basename "Found the following microservices: ${cyanf}\"${ar[*]}\"${reset}"
            print_basename "Total array length is: ${#ar[@]}"
            echo -e "\n"    
            break
         fi
      done
   else
      print_basename "INFO: Shared DB does not exist!"
   fi
}

# Reorder bash array for stop, if shared db exists
# Used for: manage all docker container
check_shared_db_stop() {
   IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
   SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
   if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
      print_basename "INFO: Shared DB exist!"
      for val in ${!ar[@]}; do
         index=${val}
         value=${ar[$val]}
         #echo "index = ${val} , value = ${ar[$val]}"
         if [ "${value}"  = "${DB_CONTAINER_NAME}" ]; then
            index_ar=${index}
            print_basename "Array index of \"${DB_CONTAINER_NAME}\" is: ${index_ar}"
            print_basename "Total array length is: ${#ar[@]}"
            print_basename "Unset value: ${DB_CONTAINER_NAME}"
            unset ar[$index_ar]
            print_basename "INFO: unset done!"
            print_basename "Total array length is: ${#ar[@]}"
            print_basename "Insert \"${DB_CONTAINER_NAME}\" on last place."
            #index_insert=0
            value_ar=${DB_CONTAINER_NAME}
            ar+=("$value_ar")
            print_basename "Found the following microservices: ${cyanf}\"${ar[*]}\"${reset}"
            print_basename "Total array length is: ${#ar[@]}"
            echo -e "\n"
            break
         fi
      done
   else
      print_basename "INFO: Shared DB does not exist!"
   fi
}


ACTION_CMDS="stop start restart update list status logs"
function join_by { local IFS="$1"; shift; echo "$*"; }

show_help() {
    echo "usage:  ${basename} [OPTIONS] ($(join_by \| $ACTION_CMDS))"
    echo " "
    echo "Actions:"
    echo " "
    echo "  stop              Stop docker microservice"
    echo "  start             Start docker microservice"
    echo "  restrat           Restart docker microservice"
    echo "  update            Update docker microservice."
    echo "  list              List all docker microservices."
    echo "  status            Status of docker microservice."
    echo "  logs              Logs of docker microservice."
    echo " "
    echo "Options:"
    echo " "
    echo "  -a, --all         Alle docker microservices. Must not be used together with OPTION -n, --name"
    echo "  -c, --config      Path to docker-compose binary; Default: \"/usr/local/bin\""
    echo "  -e, --exclude     List of excluded microservices separated by comma. Applies together with the -a option"
    echo "  -h, --help        Show help and exit."
    echo "  -n, --name        Set docker microservice name. Must not be used together with OPTION -a, --all"
    echo "  -s, --savepath    Path to save location of docker microservice; Default: \"/opt\""
    echo "  -v, --version     Show script version and exit."
    echo " "
    echo "Example1: ${basename} -c /usr/local/bin -s /opt -n CONTAINER_NAME start"
    echo "Example1: ${basename} -c /usr/local/bin -s /opt -a -e \"microservice-name1,microservice-name2,microservice-name3\""
    echo "Example1: ${basename} -a -e \"microservice-name1,microservice-name2,microservice-name3\" update"
    echo "Example2: ${basename} -n DOCKER_MICROSERVICE_NAME stop"
    echo "Example3: ${basename} -s /opt -a update"
    echo "Example3: ${basename} list"
    echo " "
}

# Variables to be read/populated based on command line
ALL_DOCKER_CONTAINER=""
DOCKER_MICROSERVICE_NAME=""
IS_START=""
IS_STOP=""
IS_RESTART=""
IS_UPDATE=""
IS_LIST=""
IS_EXCLUDE=""

# Process command line arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -a|--all)
            ALL_DOCKER_CONTAINER=1
            shift
            ;;
        -c|--config)
            IS_CONFIG="1"
            shift
            DOCKER_COMPOSE_PATH=$1
            if [[ ${IS_CONFIG} ]]; then
                # Check: Docker Compose Path entered
                if [[ ${DOCKER_COMPOSE_PATH} =~ (stop|start|restart|update|list|status|logs) ]]; then
                    print_basename "You have not entered a path to \"Docker Compose\"."
                    print_basename "Path to \"Docker Compose\" needs to be given as absolute path (starting with /)."
                    echo -e "\n"
                    show_help
                    exit 1
                fi
                # Check: Path is given as absolute path (starting with /)
                if [[ ! ${DOCKER_COMPOSE_PATH} =~ ^/ ]]; then
                    print_basename "Path to \"Docker Compose\" needs to be given as absolute path (starting with /)."
                    echo -e "\n"
                    show_help
                    exit 1
                fi
                # Check: Docker Compose Path is no File
                if [[ -f ${DOCKER_COMPOSE_PATH} ]]; then
                    print_basename "${DOCKER_COMPOSE_PATH} is a file!"
                    echo -e "\n"
                    show_help
                    exit 1
                fi
                # Check: Docker Compose Binary exists im path
                if [[ -n "${DOCKER_COMPOSE_PATH}" ]]; then
                    #echo ${DOCKER_COMPOSE_PATH}
                    if [[ -f "${DOCKER_COMPOSE_PATH}/docker-compose" ]]; then
                        print_basename "Success: Docker-Compose binary exists."
                    else
                        print_basename "ERROR: Docker-Compose binary not found: \"${DOCKER_COMPOSE_PATH}/docker-compose\""
                        exit 1
                    fi
                fi
            fi
            shift
            ;;
        -e|--exclude)
            IS_EXCLUDE="1"
            shift
            AR_EXCLUDE=$1
            shift
            ;;
        -h|--help)
            show_help
            exit
            ;;
        -n|--name)
            IS_NAME=1
            shift
            DOCKER_MICROSERVICE_NAME="$1"
            if [[ ${IS_NAME} ]]; then
                if [[ ${DOCKER_MICROSERVICE_NAME} =~ (stop|start|restart|update|list|status|logs) ]]; then
                    print_basename "Error: The entered name of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} does not exists."
                    print_basename "You have either entered no docker microservice name at all or an incorrect name"
                    print_basename "Please check your input!"
                    echo -e "\n"
                    show_help
                    exit 1                
                else
                    if [[ ${ar[*]} =~ $(echo "\<${DOCKER_MICROSERVICE_NAME}\>") ]]; then
                        print_basename "The entered name of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} exists."
                    else
                        print_basename "Error: The entered name of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} does not exists."
                        print_basename "The found docker microservices are: ${cyanf}\"$(echo ${ar[@]})\"${reset}"
                        print_basename "Please check your input!"
                        exit 1
                    fi
                fi
            fi 
            shift
            ;;
        -s|--savepath)
            IS_SAVEPATH="1"
            shift
            CONTAINER_SAVE_PATH=$1
            if [[ ${IS_SAVEPATH} ]]; then
                # Check: Docker microservice(s) entered
                if [[ ${CONTAINER_SAVE_PATH} =~ (stop|start|restart|update|list|status|logs) ]]; then
                    print_basename "You have not entered a path to Docker microservice(s)."
                    print_basename "Docker microservice(s) directory path needs to be given as absolute path (starting with /)."
                    echo -e "\n"
                    show_help
                    exit 1                 
                fi
                # Check: Path is given as absolute path (starting with /) 
                if [[ ! ${CONTAINER_SAVE_PATH} =~ ^/ ]]; then
                    print_basename "Docker microservice(s) directory path needs to be given as absolute path (starting with /)."
                    echo -e "\n"
                    show_help
                    exit 1
                fi
            fi
            shift
            ;;
        -v|--version)
            print_basename "Will show script version."
            show_version
            exit
            ;;
        -*|--*)
            print_basename "Unrecognized option: '$key'"
            print_basename "See '${basename} --help' for supported options."
            exit
        ;;
        *)    # unknown option
            POSITIONAL_ARGS+=("$key") # save it in an array for later
            shift # past argument
        ;;
    esac
done

# Print all found docker microservices
print_basename "The docker microservices are: ${cyanf}\"$(echo ${ar[@]})\"${reset}"

# Expect to get an action command as a positional argument.
if [[ -z $POSITIONAL_ARGS ]]; then
    print_basename "Please specify an action: $(join_by , $ACTION_CMDS)"
    echo ""
    show_help
    exit 1
fi

# check docker-compose binary
if [[ ! ${IS_CONFIG} ]]; then
    if [[ -n "${DOCKER_COMPOSE_PATH}" ]]; then
        #echo ${DOCKER_COMPOSE_PATH}
        if [[ -f "${DOCKER_COMPOSE_PATH}/docker-compose" ]]; then
            print_basename "Docker-Compose binary exists."
            if [[ $? -ne 0 ]]; then
                print_basename "Docker-Compose binary does not exist."
                exit 1
            fi
        else
            echo "${basename} ERROR: Docker-Compose binary did not found: '${DOCKER_COMPOSE_PATH}/docker-compose'"
            exit 1
        fi
    fi
fi

# for debug
#echo ${DOCKER_COMPOSE_PATH}
#echo ${POSITIONAL_ARGS[@]}

# Iterate over positional arguments
for POS_ARG in ${POSITIONAL_ARGS[@]}
do
    case $POS_ARG in
        start)
            #shift
            IS_START=1
            if [[ ${ALL_DOCKER_CONTAINER} ]]; then 
               print_basename "Will start all docker microservices."
            else
               print_basename "Will start docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            fi
            ;;
        stop)
            #shift
            IS_STOP=1
            if [[ ${ALL_DOCKER_CONTAINER} ]]; then
               print_basename "Will stop all docker microservices."
            else
               print_basename "Will stop docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            fi
            ;;
        restart)
            IS_RESTART=1
            if [[ ${ALL_DOCKER_CONTAINER} ]]; then
               print_basename "Will restart all docker microservices."
            else
               print_basename "Will restart docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            fi
            ;;
        update)
            IS_UPDATE=1
            if [[ ${ALL_DOCKER_CONTAINER} ]]; then
               print_basename "Will update all docker microservices."
            else
               print_basename "Will update docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            fi
            ;;
        list)
            IS_LIST=1
            print_basename "Will list all docker microservices."
            ;;
        status)
            IS_STATUS=1
            print_basename "Will show status of docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            ;;
        logs)
            IS_LOG=1
            print_basename "Will show logs of docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            ;;
        *)
            print_basename "Unrecognized action command: '$POS_ARG'"
            print_basename "See '${basename} --help' for supported options."
            exit
        ;;
    esac
done

# Check: options "-n" and "-e" must not be set at the same time
if [[ ${IS_NAME} ]] && [[ ${IS_EXCLUDE} ]]; then
    print_basename "Error: The options \"-n\" and \"-e\" must not be set at the same time"
    print_basename "Please check your input!"
    echo -e "\n"
    show_help
    exit 0
fi

# Check: options "-n" and "-a" must not be set at the same time
if [[ ${IS_NAME} ]] && [[ ${ALL_DOCKER_CONTAINER} ]]; then
    print_basename "Error: The options \"-n\" and \"-a\" must not be set at the same time"
    print_basename "Please check your input!"
    echo -e "\n"
    show_help
    exit 0
fi


# Check: entered "-e" but without "microservice name" or not entered "-a"
if [[ ${IS_EXCLUDE} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]; then
    print_basename "Error: You have either not entered \"-e\" with a \"microservice name\" to exclude or you have not entered the \"-a\" option."
    print_basename "Please check your input!"
    echo -e "\n"
    show_help
    exit 0
fi

# Check: entered to exclude microservice(s) exists in array "ar"
if [[ ${IS_EXCLUDE} ]]
then
    #echo -e "\n"
    print_basename "The following microservice(s) will be excluded from the action: ${cyanf}\"$(echo ${AR_EXCLUDE[@]})\"${reset}"

    # Initialize array "AR_EXCLUDE" and replace "," with "space"
    AR_EXCLUDE=($(echo ${AR_EXCLUDE} |sed -e 's/,/ /g'))

    # Run loop for docker microservices
    for (( j=0; j < ${#AR_EXCLUDE[@]}; j++ )); do
        # Test if the name exists in array "ar"
        VAR=
        VAR=$(echo ${AR_EXCLUDE[j]})

        if [[ ${ar[*]} =~ $(echo "\<${VAR}\>") ]]
        then
            print_basename "The entered name of docker microservice(s) ${cyanf}\"${AR_EXCLUDE[j]}\"${reset} exists."
        else
            print_basename "Error: The entered name docker microservice(s) ${cyanf}\"${AR_EXCLUDE[j]}\"${reset} does not exists."
            print_basename "Please check your input!"
            echo -e "\n"
            show_help
            exit 0
        fi
    done

    # All microservices: loop array "ar" indexes
    for val in ${!ar[@]}; do
       index=${val}
       # echo "index: ${index}"
       value=${ar[$val]}
       # echo "value: $value"

       # Excluded microservice(s): loop array "AR_EXCLUDE" indexes and compare values with values of array "ar".
       for val1 in ${!AR_EXCLUDE[@]}; do
           index1=${val1}
           #  echo "index1: ${index1}"
           value1=${AR_EXCLUDE[$val1]}
           # echo "value1: $value1"

           # If result equal excluded microservice then unset in array "ar"
           if [ "${value1}"  = "${value}" ]; then
               index_ar=${index}
               # for debug: echo "Total array length is: ${#ar[@]}"
               # for debug: echo "Unset value: ${value1}"
               unset ar[$index_ar]
               ar_excl=$(echo ${ar[@]})
               # for debug: echo ${ar_excl[@]}
           fi
       done
    done
	
    # Init array without excluded microservice(s)
    #echo ${ar_excl[@]}
    ar=($(echo ${ar_excl[@]}))
    print_basename "Array ${cyanf}\"ar\"${reset} with remaining microservices: ${cyanf}\"$(echo ${ar[@]})\"${reset}"
fi

# 
#print_basename "All Script Arguments are: ${cyanf}\"${SCRIPT_ARG}\"${reset}"
#echo -n "${SCRIPT_ARG}"
#CHECK_INPUT_DATA=$(echo -n "${SCRIPT_ARG}" | sed -e 's/\<stop\>//;s/\<start\>//;s/\<restart\>//;s/update//;s/list//;s/status//;s/logs//')
#INPUT_MS_NAME=$(echo -n "${CHECK_INPUT_DATA}" |sed -e 's/-n //;s/ //')
#echo ""
#echo -n "$VAR1"
#echo ""
#echo ${ar[*]}

#exit 0

RES1=""
COMMAND=${DOCKER_COMPOSE_PATH}/docker-compose
# Start docker container
if [[ ${IS_START} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]
then
    start_dc

    # Print success message if RES1=0
    print_success "Starting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"

    print_end

    # Print error message if RES1=1
    print_error "Error starting docker microservice"
    exit 0
fi

# Stop docker container
if [[ ${IS_STOP} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]
then
    stop_dc

    # Print success message if RES1=0
    print_success "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    print_end

    # Print error message if RES1=1
    print_error
    exit 0
fi

# Restart docker container
if [[ ${IS_RESTART} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]
then
    stop_dc
    print_foot
    start_dc

    # Print success message if RES1=0
    print_success "Restarting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"

    print_end

    # Print error message if RES1=1
    print_error "Error restarting docker microservice"
    exit 0
fi

# Update docker container
if [[ ${IS_UPDATE} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]; then
    # run update
    update_dc

    # Print success message if RES1=0
    print_success "Updating docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"

    # Print error message if RES1=1
    print_error "Error updating docker microservice!"
    exit 0
fi

# List all docker container
# format="%8s%10s%10s%14s\n"
#printf "$format" "Dirs" "Files" "Blocks" "Directory"
#  printf "%-20s %-27s\t %1s %-5s\n" "Docker microservice:" "${cyanf} $i${reset}" "-" "${bluef}${_STATUS_DMS}${reset}"
if [[ ${IS_LIST} ]]; then
    #print_basename "All docker container are being listed..."
    print_basename "All docker microservices are being listed..."
    print_kopf

    for i in ${ar[*]}; do
       arg=
       arg=$i
       status_dms "$arg"
       if [[ ${_STATUS_DMS} = running ]]
       then
          #echo "Docker microservice:${cyanf} $i${reset} - ${bluef}${_STATUS_DMS}${reset}"
          printf "%-20s %-27s %1s %-5s\n" "Docker microservice:" "${cyanf} $i${reset}" "-" "${bluef}${_STATUS_DMS}${reset}"
       else 
          #echo "Docker microservice:${cyanf} $i${reset} - ${redf}${_STATUS_DMS}${reset}"
          printf "%-20s %-27s %1s %-5s\n" "Docker microservice:" "${cyanf} $i${reset}" "-" "${redf}${_STATUS_DMS}${reset}"
       fi
    done

    # Print success message if RES1=0
    print_success "Listing all docker microservices done!"
    print_foot

    # Print error message if RES1=1
    print_error "Error listing all docker microservices!"
    exit 0
fi

# Show status of docker microservices
if [[ ${IS_STATUS} ]]; then
    print_basename "Status of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being showed..."
    print_kopf

    cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
    echo "RUN: ${COMMAND} ps"
    ${COMMAND} ps

    # Print success message if RES1=0
    print_success "Showing status of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    print_foot

    # Print error message if RES1=1
    print_error "Error schowing status of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
    exit 0
fi

# Show logs of docker container
if [[ ${IS_LOG} ]]; then
    print_basename "Last 1000 log lines of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} are being showed..."
    print_kopf

    cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
    echo "RUN: ${COMMAND} logs --tail=1000"
    ${COMMAND} logs --tail=1000

    # Print success message if RES1=0
    print_success "Showing logs of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    print_foot

    # Print error message if RES1=1
    print_error "Error schowing logs of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
    exit 0
fi

# manage all docker container
if  [[ ${ALL_DOCKER_CONTAINER} ]]; then
   # start all docker container
   if [[ ${IS_START} ]]; then
      # Print message
      echo -e "\n"
      print_basename "======== *** Starting ${cyanf}\"all\"${reset} docker microservice!!! *** ========"
      echo ""
    
      # Reorder bash array for start, if shared db exists
      check_shared_db_start

      # loop to start all docker container
      for DOCKER_MICROSERVICE_NAME in ${ar[*]}; do
         # start container for Option: -a
         #dc_status
         start_dc_all

         # Print success message if RES1=0
         print_success "Starting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"

         # Print error message if RES1=1
         print_error "Error starting docker microservice!"
      done
      exit 0
   fi

   # stop all docker container
   if [[ ${IS_STOP} ]]; then
      # Print message
      echo -e "\n"
      print_basename "======== *** Stopping ${cyanf}\"all\"${reset} docker microservice!!! *** ========"
      echo -e "\n"
      
      # Reorder bash array for stop, if shared db exists
      check_shared_db_stop

      # loop to stop all docker container
      for DOCKER_MICROSERVICE_NAME in ${ar[*]}; do         
         # stop container for Option: -a
         #dc_status        
         stop_dc_all

         # Print success message if RES1=0
         print_success "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"

         # Print error message if RES1=1
         print_error "Error stopping docker microservice!"
      done
      exit 0
   fi

   # restart all docker container
   if [[ ${IS_RESTART} ]]; then
      # Print message
      echo -e "\n"
      print_basename "======== *** Stopping ${cyanf}\"all\"${reset} docker microservice!!! *** ========"
      echo -e "\n"

      # Reorder bash array for stop, if shared db exists
      check_shared_db_stop

      # stop loop for all docker container
      for DOCKER_MICROSERVICE_NAME in ${ar[*]}; do
        # stop container for Option: -a
        #dc_status 
        stop_dc_all

         # Print success message if RES1=0
         print_success "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"         

         # Print error message if RES1=1
         print_error "Error stopping docker microservice!"
      done

      # Print message
      if [[ ${RES1} == 0 ]]; then        
         print_basename "======== *** Stopping ${cyanf}\"all\"${reset} docker microservices done!!! *** ========"
         print_end
      fi

      # Print message
      echo -e "\n\n"
      print_basename "======== *** Starting ${cyanf}\"all\"${reset} docker microservice!!! *** ========"
      echo ""
      # Reorder bash array for stop, if shared db exists
      check_shared_db_start

      # stop loop for all docker container
      for DOCKER_MICROSERVICE_NAME in ${ar[*]}; do
         # start container for Option: -a
         #dc_status
         start_dc_all

         # Print success message if RES1=0
         print_success "Restarting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"

         # Print error message if RES1=1
         print_error "Error starting docker microservice!"
      done

      # Print message
      if [[ ${RES1} == 0 ]]; then
         print_basename "======== *** Starting ${cyanf}\"all\"${reset} docker microservice done!!! *** ========"
         print_end
      fi
      exit 0
   fi

   # Update all docker container
   if [[ ${IS_UPDATE} ]]; then
      echo ""
      print_basename "======== *** Updating ${cyanf}\"all\"${reset} docker microservice!!! *** ========"

      # Reorder bash array for stop, if shared db exists
      check_shared_db_stop

      # loop for all docker container
      for DOCKER_MICROSERVICE_NAME in ${ar[*]}; do
         # update container for Option: -a
         #dc_status
         update_dc

         # Print success message if RES1=0
         print_success "Updating docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         echo ""

         # Print error message if RES1=1
         print_error "Error updating docker microservice!"
      done

      # Print message
      if [[ ${RES1} == 0 ]]; then
         print_basename "======== *** Updating ${cyanf}\"all\"${reset} docker microservices done!!! *** ========"
         print_end
      fi

      exit 0
   fi
fi

