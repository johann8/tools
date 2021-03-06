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
SCRIPT_VERSION="0.3.1"                  # Set script version
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")  # time stamp
# Shared DB between containers
DB_CONTAINER_NAME=mariadb               # The name of MySQL / MariaDB container
DB_NETWORK=mysqlNet                     # The name of network of MySQL / MariaDB container
HYPHEN_ON=false                         # Docker microservice name may contain only: letters and numbers; Letters, numper and hyphen: false
SCRIPT_ARG=$(for arg in "$*"; do echo "$arg"; done)

# Set Pathes
DOCKER_COMPOSE_PATH=""
DOCKER_COMPOSE_PATH="${DOCKER_COMPOSE_PATH:-/usr/local/bin}"

DEFAULT_CONTAINER_SAVE_PATH="/opt"
if [[ -f ${DOCKER_COMPOSE_PATH}/docker-compose ]]
then
    FIND_CONTAINER_SAVE_PATH=$(find ${DEFAULT_CONTAINER_SAVE_PATH} -name docker-compose.yml |uniq |head -1 |sed 's+/[^/]*$++' |sed 's+/[^/]*$++')
    CONTAINER_SAVE_PATH=${FIND_CONTAINER_SAVE_PATH}
    #CONTAINER_SAVE_PATH="${CONTAINER_SAVE_PATH:-/opt}"
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

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################
#
### define functions
#

# ======= Functions =========
# print error
error_exit() {
    if [[ ! -z $1 ]]
    then
        print_basename "$1 returned non-zero exit code: terminating"
    fi
    exit 1
}

# Function print kopf
print_kopf() {
    #echo ""
    echo "${greenf}=====================================================${reset}"
}

# Function print foot
print_foot() {
   echo "${greenf}-----------------------------------------------------${reset}"
   echo ""
}

# Function print end
 print_end() {
   echo "${greenf}************************************************************${reset}"
   echo ""
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
    3)  echo -n "$1 [$2]: "; read _answer
        if [[ ! "$_answer" = [y,n] ]]; then
                         echo ""; f_error "***ERROR: Please enter \"y\" or \"n\"."; echo ""
        else
            cmd="$3=\"$_answer\""
            eval $cmd; ans=1
        fi
    ;;
    2)  echo -n "$1: "; read _answer
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
         if [ "${A_ANSWER}" = "y" ]
         then
            print_basename "The answer is: ${greenf}\"${A_ANSWER}\"${reset}"
            # loop for all docker containers and start them
            for DOCKER_MICROSERVICE_NAME in ${ar_db[*]}; do
               print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being started..."
               print_kopf
               cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
               print_basename "RUN: ${COMMAND} up -d"
               ${COMMAND} up -d
               sleep 5
               print_basename "RUN: ${COMMAND} ps"
               ${COMMAND} ps

               if [[ $? -ne 0 ]]
               then
                  RES1=1
               fi

               print_foot
               if [[ ${RES1} == 1 ]]
               then
                  error_exit "'Error starting docker container'"
                  exit 0
               fi
               print_basename "Starting docker container ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
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
#start_dc() {
#    # start
#    print_basename "Docker container ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being started..."
#    print_kopf
#    cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
#    echo "RUN: ${COMMAND} up -d"
#    ${COMMAND} up -d
#    echo "" && sleep 5
#    echo "RUN: ${COMMAND} ps"
#    ${COMMAND} ps
#}

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
         if [ "${A_ANSWER}" = "y" ]
         then
            print_basename "The answer is: ${greenf}\"${A_ANSWER}\"${reset}"
            # loop for all docker containers and stop them
            for DOCKER_MICROSERVICE_NAME in ${ar_db[*]}; do
               print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being stoped..."
               print_kopf
               cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
               print_basename "RUN: ${COMMAND} down"
               ${COMMAND} down
               sleep 5
               print_basename "RUN: ${COMMAND} ps"
               ${COMMAND} ps

               if [[ $? -ne 0 ]]
               then
                  RES1=1
               fi

               print_foot
               if [[ ${RES1} == 1 ]]
               then
                  error_exit "'Error stopping docker microservice'"
                  exit 0
               fi
               print_basename "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
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

# Function update docker container
# Es gibt ein Problem, wenn kein update.sh vorhanden und microservice Name nicht gleich dem container Namen
update_dc() {
   # check, if update.sh exists
   if [[ -f ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}/update.sh ]]
   then
      # read docker container image from update.sh
      print_basename "Script ${cyanf}\"${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}/update.sh\"${reset} exists."
      CONTAINER_NAME=$(cat ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}/update.sh |grep -w "^IMAGE_NAME" | awk -F'=' '{print $2}')
      print_basename "Docker container image is: ${cyanf}\"${CONTAINER_NAME}\"${reset}"
   else
      # read docker container image from docker-compose.yml
      #CONTAINER_NAME=$(cat ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}/docker-compose.yml |grep container_name |awk -F':' '{print $2}' |sed 's/ //' |grep "^${DOCKER_MICROSERVICE_NAME}")
      ar_cn=($(cat ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}/docker-compose.yml |grep container_name |awk -F':' '{print $2}' |sed 's/ //'))

      # check: var CONTAINER_NAME is empty or not
      if [[ ${ar_cn[*]} =~ $(echo "\<${DOCKER_MICROSERVICE_NAME}\>") ]]
      then
          CONTAINER_NAME=${DOCKER_MICROSERVICE_NAME}
          print_basename "Docker container name is: ${cyanf}\"${CONTAINER_NAME}\"${reset}"
      else
          print_basename "ERROR: Docker container name ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} does not exist!"
          print_basename "Please define Docker container name unter: ${cyanf}\"${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}/update.sh\"${reset}"
          exit 0
      fi
   fi

   echo ${greenf}=================================================================${reset}
   echo "  Start updating Docker Microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} am ${TIMESTAMP}"
   echo ${greenf}=================================================================${reset}
   #
   # Get container id
   CONTAINER_ID="$(docker ps -a --format "{{.ID}}" --filter name=^/"${CONTAINER_NAME}"$)"

   # Get the image and hash of the running container
   CONTAINER_IMAGE="$(docker inspect --format "{{.Config.Image}}" --type container ${CONTAINER_ID})"

   RUNNING_IMAGE="$(docker inspect --format "{{.Image}}" --type container "${CONTAINER_ID}")"
   echo " "
   print_basename "${greenf}Running Image:${pinkf} ${RUNNING_IMAGE} ${reset}"
   echo " "

   # Pull in latest version of the container and get the hash
   docker pull "${CONTAINER_IMAGE}"
   LATEST_IMAGE="$(docker inspect --format "{{.Id}}" --type image "${CONTAINER_IMAGE}")"
   echo " "
   print_basename "${greenf}Latest Image:${bluef} ${LATEST_IMAGE} ${reset}"

   # Update / Exit
   if ! [ ${RUNNING_IMAGE} = ${LATEST_IMAGE} ]; then
      echo " "
      echo ${greenf}======================== ${cyanf}Message ${greenf}========================${reset}
      print_basename "Update from docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is started..."
      
      # dc pull other images of microservice
      cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
      ${COMMAND} pull

      stop_dc
      print_foot
      start_dc
      print_foot
      echo " "
      
      # remove old images
      docker rmi $(docker images -f "dangling=true" -q --no-trunc)
   else
      echo " "
      echo ${greenf}======================== ${cyanf}Message ${greenf}========================${reset}
      print_basename "There is no update from docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}."
   fi
}

# check if container is running
dc_status() {
   _DC_STATUS=$( docker ps -a -f name=${DOCKER_MICROSERVICE_NAME} | grep ${DOCKER_MICROSERVICE_NAME} 2> /dev/null )
   if [[ ! -z ${_DC_STATUS} ]]; then
      print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} has status: $( echo ${_DC_STATUS} | awk '{ print $7 }' )"
   else
      print_basename "Docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} has status: Down"
      break
   fi
}

# Reorder bash array for start, if shared db exists
check_shared_db_start() {
   IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
   SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
   if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
      print_basename "INFO: Shared DB exist!"
      for val in ${!ar[@]}
      do
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
check_shared_db_stop() {
   IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
   SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
   if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
      print_basename "INFO: Shared DB exist!"
      for val in ${!ar[@]}
      do
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
                if [[ -n "${DOCKER_COMPOSE_PATH}" ]]
                then
                    #echo ${DOCKER_COMPOSE_PATH}
                    if [[ -f "${DOCKER_COMPOSE_PATH}/docker-compose" ]]
                    then
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
            DOCKER_MICROSERVICE_NAME=$1
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
if [[ -z $POSITIONAL_ARGS ]]
then
    print_basename "Please specify an action: $(join_by , $ACTION_CMDS)"
    echo ""
    show_help
    exit 1
fi

# check docker-compose binary
if [[ ! ${IS_CONFIG} ]]
then
    if [[ -n "${DOCKER_COMPOSE_PATH}" ]]
    then
        #echo ${DOCKER_COMPOSE_PATH}
        if [[ -f "${DOCKER_COMPOSE_PATH}/docker-compose" ]]
        then
            print_basename "Docker-Compose binary exists."
            if [[ $? -ne 0 ]]
            then
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
            if [[ ${ALL_DOCKER_CONTAINER} ]]
            then 
               print_basename "Will start all docker microservices."
            else
               print_basename "Will start docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            fi
            ;;
        stop)
            #shift
            IS_STOP=1
            if [[ ${ALL_DOCKER_CONTAINER} ]]
            then
               print_basename "Will stop all docker microservices."
            else
               print_basename "Will stop docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            fi
            ;;
        restart)
            IS_RESTART=1
            if [[ ${ALL_DOCKER_CONTAINER} ]]
            then
               print_basename "Will restart all docker microservices."
            else
               print_basename "Will restart docker microservice: ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
            fi
            ;;
        update)
            IS_UPDATE=1
            if [[ ${ALL_DOCKER_CONTAINER} ]]
            then
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
if [[ ${IS_NAME} ]] && [[ ${IS_EXCLUDE} ]]
then
    print_basename "Error: The options \"-n\" and \"-e\" must not be set at the same time"
    print_basename "Please check your input!"
    echo -e "\n"
    show_help
    exit 0
fi

# Check: options "-n" and "-a" must not be set at the same time
if [[ ${IS_NAME} ]] && [[ ${ALL_DOCKER_CONTAINER} ]]
then
    print_basename "Error: The options \"-n\" and \"-a\" must not be set at the same time"
    print_basename "Please check your input!"
    echo -e "\n"
    show_help
    exit 0
fi


# Check: entered "-e" but without "microservice name" or not entered "-a"
if [[ ${IS_EXCLUDE} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]
then
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
    for (( j=0; j < ${#AR_EXCLUDE[@]}; j++ ))
    do
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
    for val in ${!ar[@]}
    do
       index=${val}
       # echo "index: ${index}"
       value=${ar[$val]}
       # echo "value: $value"

       # Excluded microservice(s): loop array "AR_EXCLUDE" indexes and compare values with values of array "ar".
       for val1 in ${!AR_EXCLUDE[@]}
       do
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

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_end
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error starting docker microservice'"
    fi
    print_basename "Starting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    exit 0
fi

# Stop docker container
if [[ ${IS_STOP} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]
then
    stop_dc

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_end
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error stopping docker microservice'"
    fi
    print_basename "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    exit 0
fi

# Restart docker container
if [[ ${IS_RESTART} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]
then
    stop_dc
    print_foot
    start_dc

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    # print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error restarting docker microservices!"
    fi
    print_end
    print_basename "Restarting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    exit 0
fi

# Update docker container
if [[ ${IS_UPDATE} ]] && [[ ! ${ALL_DOCKER_CONTAINER} ]]
then
    update_dc

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_end
    #echo ""
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error updating docker microservice'"
    fi
    print_basename "Updating docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    exit 0
fi

# List all docker container
if [[ ${IS_LIST} ]]
then
    #print_basename "All docker container are being listed..."
    print_basename "All docker microservices are being listed..."
    print_kopf

    for i in ${ar[*]}; do
       echo "Docker microservice:${cyanf} $i ${reset}"
    done

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error listing all docker microservices'"
    fi
    print_basename "Listing all docker microservices done!"
    exit 0
fi

# Show status of docker microservices
if [[ ${IS_STATUS} ]]
then
    print_basename "Status of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} is being showed..."
    print_kopf

    cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
    echo "RUN: ${COMMAND} ps"
    ${COMMAND} ps

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error schowing status of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
    fi
    print_basename "Showing status of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    exit 0
fi

# Show logs of docker container
if [[ ${IS_LOG} ]]
then
    print_basename "Last 1000 log lines of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} are being showed..."
    print_kopf

    cd ${CONTAINER_SAVE_PATH}/${DOCKER_MICROSERVICE_NAME}
    echo "RUN: ${COMMAND} logs --tail=1000"
    ${COMMAND} logs --tail=1000

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error schowing logs of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset}"
    fi
    print_basename "Showing logs of docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
    exit 0
fi

# manage all docker container
if  [[ ${ALL_DOCKER_CONTAINER} ]]
then
   # start all docker container
   if [[ ${IS_START} ]]
   then
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

         if [[ $? -ne 0 ]]
         then
            RES1=1
         fi

         if [[ ${RES1} == 1 ]]
         then
            error_exit "'Error starting docker microservice'"
         fi
         print_basename "Sarting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"
      done
      exit 0
   fi

   # stop all docker container
   if [[ ${IS_STOP} ]]
   then
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

         if [[ $? -ne 0 ]]
         then
            RES1=1
         fi

         #print_foot
         if [[ ${RES1} == 1 ]]
         then
            error_exit "'Error stopping docker microservice'"
         fi
         print_basename "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"  
      done
      exit 0
   fi

   # restart all docker container
   if [[ ${IS_RESTART} ]]
   then
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

         if [[ $? -ne 0 ]]
         then
            RES1=1
         else
            RES_STOP=1
         fi

         if [[ ${RES1} == 1 ]]
         then
             error_exit "'Error stoping docker microservice'"
             exit 0
         fi
         print_basename "Stopping docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"
      done

      # Print message
      if [[ ${RES_STOP} == 1 ]]
      then        
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

         if [[ $? -ne 0 ]]
         then
            RES1=1
         else
            RES_START=1
         fi

         if [[ ${RES1} == 1 ]]
         then
             error_exit "'Error starting docker microservice'"
             exit 0
         fi
         print_basename "Restarting docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         echo -e "\n"
      done

      # Print message
      if [[ ${RES_START} == 1 ]]
      then
         print_basename "======== *** Starting ${cyanf}\"all\"${reset} docker microservice done!!! *** ========"
         print_end
      fi

      exit 0
   fi

   # Update all docker container
   if [[ ${IS_UPDATE} ]]
   then
      #echo -e "\n"
      echo ""
      print_basename "======== *** Updating ${cyanf}\"all\"${reset} docker microservice!!! *** ========"
      #echo -e "\n"

      # Reorder bash array for stop, if shared db exists
      check_shared_db_stop

      # loop for all docker container
      for DOCKER_MICROSERVICE_NAME in ${ar[*]}; do
         # update container for Option: -a
         #dc_status
         update_dc

         if [[ $? -ne 0 ]]
         then
            RES1=1
         else
            RES_START=1
         fi

         print_foot
         if [[ ${RES1} == 1 ]]
         then
             error_exit "'Error updating docker microservice'"
         fi
         print_basename "Updating docker microservice ${cyanf}\"${DOCKER_MICROSERVICE_NAME}\"${reset} done!"
         print_end
         #echo -e "\n"
         echo ""
      done

      # Print message
      if [[ ${RES_START} == 1 ]]
      then
         print_basename "======== *** Updating ${cyanf}\"all\"${reset} docker microservices done!!! *** ========"
         print_end
      fi

      exit 0
   fi
fi

