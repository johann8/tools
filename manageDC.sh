#!/bin/bash
#
# Debug enable
#set -x
#
set -o errexit

# set vars
basename="${0##*/}"
# Shared DB between containers
DB_CONTAINER_NAME=mariadb
DB_NETWORK=mysqlNet

# define colors
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"; xxxf="${esc}[1;32m"
boldon="${esc}[1m"; boldoff="${esc}[22m"
reset="${esc}[0m"

# define functions
#
# ======= Functions =========
error_exit() {
    if [[ ! -z $1 ]]
    then
        print_basename "$1 returned non-zero exit code: terminating"
    fi
    exit 1
}

# Print script name
print_basename() {
   echo "${pinkf}${basename}:${reset} $1"
}

# Function print kopf
print_kopf() {
    echo ""
    echo "${greenf}============================${reset}"
}

# Function print foot
print_foot() {
    echo "${greenf}----------------------------${reset}"
    echo ""
}

# Print error message in red
f_error() {
 echo ${redf}$1${reset}
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
    # start
    print_basename "Docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} is being started..."
    print_kopf
    cd ${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}
    echo "RUN: ${COMMAND} up -d"
    ${COMMAND} up -d
    echo "" && sleep 5
    echo "RUN: ${COMMAND} ps"
    ${COMMAND} ps
}

# Function stop docker container
stop_dc() {
   #
   if [[ ${DOCKER_CONTAINER_NAME} == ${DB_CONTAINER_NAME} ]]
   then
      echo "Check if database mariadb is shared"
      IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
      SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${MYSQL_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
      ar_db=($(grep -r -o ${DB_CONTAINER_NAME}_${DB_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml |uniq | awk -F'/' '{print $3}'))

      # Check if Shared DB exist
      if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
         echo "INFO: Shared DB exist!"
         echo "Docker container with shared DB are: \"${ar_db[*]}\""
         echo "Total array length is: ${#ar_db[@]}"
         echo "Insert \"${DB_CONTAINER_NAME}\" on last place"
         value_ar=${DB_CONTAINER_NAME}
         ar_db+=("$value_ar")
         echo "Total array length is: ${#ar_db[@]}"
         echo "Found the following microservices: ${cyanf}\"${ar_db[*]}\"${reset}"
         echo ""
         echo "To stop container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset}, other containers must be stopped as well:  ${cyanf}\"${ar_db[*]}\"${reset}"
         echo ""
         f_promtConfigYN "Do you also want to stop these containers?" "y/n" "A_ANSWER"

         # Stop all containers with shared MariaDB
         if [ "${A_ANSWER}" = "y" ]
         then
            echo "The answer is: ${greenf}\"${A_ANSWER}\"${reset}"
            # loop for all docker containers and stop them
            for DOCKER_CONTAINER_NAME in ${ar_db[*]}; do
               print_basename "Docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} is being stoped..."
               print_kopf
               cd ${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}
               echo "RUN: ${COMMAND} down"
               ${COMMAND} down
               echo "" && sleep 5
               echo "RUN: ${COMMAND} ps"
               ${COMMAND} ps

               if [[ $? -ne 0 ]]
               then
                  RES1=1
               fi

               print_foot
               if [[ ${RES1} == 1 ]]
               then
                  error_exit "'Error stopping docker container'"
               fi
               print_basename "Stopping docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
               echo ""
            done
            exit 0
         else
            echo "The answer is: ${redf}\"${A_ANSWER}\"${reset} "
            print_basename "Stopping of docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} is canceled!"
            exit 0
         fi
      else
         echo "INFO: Shared DB does not exist!"
         # stop container
         print_basename "Docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} is being stoped..."
         print_kopf
         cd ${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}
         echo "RUN: ${COMMAND} down"
         ${COMMAND} down
         echo "" && sleep 5
         echo "RUN: ${COMMAND} ps"
         ${COMMAND} ps
      fi
   else
       # stop
       print_basename "Docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} is being stoped..."
       print_kopf
       cd ${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}
       echo "RUN: ${COMMAND} down"
       ${COMMAND} down
       echo "" && sleep 5
       echo "RUN: ${COMMAND} ps"
       ${COMMAND} ps
   fi
}

# Function update docker container
update_dc() {
    print_basename "Docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} is being updated..."
    cd ${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}
    (${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}/update.sh)
    echo "" && sleep 5
    print_kopf
    echo "RUN: ${COMMAND} ps"
    ${COMMAND} ps
}

# Reorder bash array for start, if shared db exists
check_shared_db_start() {
   DB_CONTAINER_NAME=mariadb
   MYSQL_NETWORK=mysqlNet
   IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
   SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${MYSQL_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
   if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
      echo "INFO: Shared DB exist!"
      for val in ${!ar[@]}
      do
         index=${val}
         value=${ar[$val]}
         #echo "index = ${val} , value = ${ar[$val]}"
         if [ "${value}"  = "${DB_CONTAINER_NAME}" ]; then
            index_ar=${index}
            echo "Array index of \"${DB_CONTAINER_NAME}\" is: ${index_ar}"
            echo "Total array length is: ${#ar[@]}"
            echo "Unset value: ${DB_CONTAINER_NAME}"
            unset ar[$index_ar] && echo "INFO: unset done!"
            echo "Total array length is: ${#ar[@]}"
            echo "Insert \"${DB_CONTAINER_NAME}\" on first place"
            index_insert=0
            value_ar=${DB_CONTAINER_NAME}
            ar=("${ar[@]:0:$index_insert}" "$value_ar" "${ar[@]:$index_insert}") && echo "INFO: insert done!"
            echo "Found the following microservices: ${cyanf}\"${ar[*]}\"${reset}"
            echo "Total array length is: ${#ar[@]}"
            break
         fi
      done
   else
      echo "INFO: Shared DB does not exist!"
   fi
}

# Reorder bash array for stop, if shared db exists
check_shared_db_stop() {
   DB_CONTAINER_NAME=mariadb
   MYSQL_NETWORK=mysqlNet
   IN_AR=$(echo ${ar[@]} | grep -o ${DB_CONTAINER_NAME} | wc -w)
   SHARED_MYSQL=$(grep -r -o ${DB_CONTAINER_NAME}_${MYSQL_NETWORK} ${CONTAINER_SAVE_PATH}/*/docker-compose.yml | uniq |wc -l)
   if [ "${IN_AR}" -ge 1 ] && [ "${SHARED_MYSQL}" -ge 1 ]; then
      echo "INFO: Shared DB exist!"
      for val in ${!ar[@]}
      do
         index=${val}
         value=${ar[$val]}
         #echo "index = ${val} , value = ${ar[$val]}"
         if [ "${value}"  = "${DB_CONTAINER_NAME}" ]; then
            index_ar=${index}
            echo "Array index of \"${DB_CONTAINER_NAME}\" is: ${index_ar}"
            echo "Total array length is: ${#ar[@]}"
            echo "Unset value: ${DB_CONTAINER_NAME}"
            unset ar[$index_ar] && echo "INFO: unset done!"
            echo "Total array length is: ${#ar[@]}"
            echo "Insert \"${DB_CONTAINER_NAME}\" on last place."
            #index_insert=0
            value_ar=${DB_CONTAINER_NAME}
            ar+=("$value_ar")
            echo "Found the following microservices: ${cyanf}\"${ar[*]}\"${reset}"
            echo "Total array length is: ${#ar[@]}"
            break
         fi
      done
   else
      echo "INFO: Shared DB does not exist!"
   fi
}


ACTION_CMDS="stop start restart update list status logs"
function join_by { local IFS="$1"; shift; echo "$*"; }

show_help() {
    echo "usage:  ${basename} [OPTIONS] ($(join_by \| $ACTION_CMDS))"
    echo " "
    echo "Actions:"
    echo " "
    echo "  stop              Stop docker container"
    echo "  start             Start docker container"
    echo "  restrat           Restart docker container"
    echo "  update            Update docker container."
    echo "  list              List all docker microservices."
    echo "  status            Status of docker container."
    echo "  logs              Logs of docker container."
    echo " "
    echo "Options:"
    echo " "
    echo "  -a, --all         Alle docker container. Must not be used together with OPTION -n, --name"
    echo "  -c, --config      Path to docker-compose binary; Default: /usr/local/bin"
    echo "  -h, --help        Show help and exit."
    echo "  -n, --name        Set docker container name. Must not be used together with OPTION -a, --all"
    echo "  -s, --savepath    Path to save location of docker container; Default: /opt"
    echo " "
    echo "Example1: ${basename} -c /usr/bin -s /opt/containerName -n CONTAINER_NAME start"
    echo "Example2: ${basename} -n CONTAINER_NAME stop"
    echo "Example3: ${basename} -s /opt/containerName -a update"
    echo "Example3: ${basename} list"
    echo " "
}

# Variables to be read/populated based on command line
DOCKER_COMPOSE_PATH="${DOCKER_COMPOSE_PATH:-/usr/local/bin}"
CONTAINER_SAVE_PATH="${CONTAINER_SAVE_PATH:-/opt}"
ALL_DOCKER_CONTAINER=""
DOCKER_CONTAINER_NAME=""
IS_START=""
IS_STOP=""
IS_RESTART=""
IS_UPDATE=""
IS_LIST=""

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
            shift
            DOCKER_COMPOSE_PATH=$1
            shift
            ;;
        -h|--help)
            show_help
            exit
            ;;
        -n|--name)
            shift
            DOCKER_CONTAINER_NAME=$1
            shift
            ;;
        -s|--savepath)
            shift
            CONTAINER_SAVE_PATH=$1
            shift
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

# Expect to get an action command as a positional argument.
if [[ -z $POSITIONAL_ARGS ]]
then
    print_basename "Please specify an action: $(join_by , $ACTION_CMDS)"
    echo ""
    show_help
    exit 1
fi

# check docker-compose binary
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
            print_basename "Will start docker container."
            ;;
        stop)
            #shift
            IS_STOP=1
            print_basename "Will stop docker container."
            ;;
        restart)
            IS_RESTART=1
            print_basename "Will restart docker container."
            ;;
        update)
            IS_UPDATE=1
            print_basename "Will update docker container."
            ;;
        list)
            IS_LIST=1
            print_basename "Will list all docker microservices."
            ;;
        status)
            IS_STATUS=1
            print_basename "Will show status of docker microservice."
            ;;
        logs)
            IS_LOG=1
            print_basename "Will show logs of docker microservice."
            ;;
        *)
            print_basename "Unrecognized action command: '$POS_ARG'"
            print_basename "See '${basename} --help' for supported options."
            exit
        ;;
    esac
done


# get all docker microservices and save in an array
# The name must contain only letters and numbers
#ar=($(find ${CONTAINER_SAVE_PATH} -maxdepth 2 -name docker-compose.yml| awk -F'/' '{print $3}'))
ar=($(find ${CONTAINER_SAVE_PATH} -maxdepth 2 -name docker-compose.yml| awk -F'/' '{print $3}' | grep -v '[^A-Za-z0-9]'))

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

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error starting docker container '"
    fi
    print_basename "Sarting docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
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

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error stopping docker container'"
    fi
    print_basename "Stopping docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
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

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error restarting docker container'"
    fi
    print_basename "Restarting docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
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

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error updating docker container'"
    fi
    print_basename "Updating docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
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
    print_basename "Status of docker microservice ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} is being showed..."
    print_kopf

    cd ${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}
    echo "RUN: ${COMMAND} ps"
    ${COMMAND} ps

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error schowing status of docker microservice ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset}"
    fi
    print_basename "Schowing status of docker microservice ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
    exit 0
fi

# Show logs of docker container
if [[ ${IS_LOG} ]]
then
    print_basename "Last 1000 log lines of docker microservice ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} are being showed..."
    print_kopf

    cd ${CONTAINER_SAVE_PATH}/${DOCKER_CONTAINER_NAME}
    echo "RUN: ${COMMAND} logs --tail=1000"
    ${COMMAND} logs --tail=1000

    if [[ $? -ne 0 ]]
    then
       RES1=1
    fi

    print_foot
    if [[ ${RES1} == 1 ]]
    then
        error_exit "'Error schowing logs of docker microservice ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset}"
    fi
    print_basename "Schowing logs of docker microservice ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
    exit 0
fi

# manage all docker container
if  [[ ${ALL_DOCKER_CONTAINER} ]]
then
   # start all docker container
   if [[ ${IS_START} ]]
   then
      # Reorder bash array for start, if shared db exists
      check_shared_db_start

      # loop for all docker container
      for DOCKER_CONTAINER_NAME in ${ar[*]}; do
         start_dc

         if [[ $? -ne 0 ]]
         then
            RES1=1
         fi

         print_foot
         if [[ ${RES1} == 1 ]]
         then
            error_exit "'Error starting docker container '"
         fi
         print_basename "Sarting docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
         echo ""
      done
      exit 0
   fi

   # stop all docker container
   if [[ ${IS_STOP} ]]
   then
      # Reorder bash array for stop, if shared db exists
      check_shared_db_stop

      # loop for all docker container
      for DOCKER_CONTAINER_NAME in ${ar[*]}; do
         stop_dc

         if [[ $? -ne 0 ]]
         then
            RES1=1
         fi

         print_foot
         if [[ ${RES1} == 1 ]]
         then
            error_exit "'Error stopping docker container'"
         fi
         print_basename "Stopping docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
         echo ""
      done
      exit 0
   fi

   # restart all docker container
   if [[ ${IS_RESTART} ]]
   then
      # Print message
      print_basename "===== *** Stopping ${cyanf}\"all\"${reset} docker container!!! *** ====="

      # Reorder bash array for stop, if shared db exists
      check_shared_db_stop

      # stop loop for all docker container
      for DOCKER_CONTAINER_NAME in ${ar[*]}; do
         stop_dc
         print_foot

         if [[ $? -ne 0 ]]
         then
            RES1=1
         else
            RES_STOP=1
         fi

         print_foot
         if [[ ${RES1} == 1 ]]
         then
             error_exit "'Error stoping docker container'"
             exit 0
         fi
         print_basename "Stopping docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
         echo " "
      done

      # Print message
      if [[ ${RES_STOP} == 1 ]]
      then
         print_basename "Stopping ${cyanf}\"all\"${reset} docker container done!"
         echo " "
      fi

      # Print message
      print_basename "===== *** Retarting ${cyanf}\"all\"${reset} docker container!!! *** ====="

      # Reorder bash array for stop, if shared db exists
      check_shared_db_start

      # stop loop for all docker container
      for DOCKER_CONTAINER_NAME in ${ar[*]}; do
         start_dc
         print_foot

         if [[ $? -ne 0 ]]
         then
            RES1=1
         else
            RES_START=1
         fi

         print_foot
         if [[ ${RES1} == 1 ]]
         then
             error_exit "'Error starting docker container'"
             exit 0
         fi
         print_basename "Restarting docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
         echo " "
      done

      # Print message
      if [[ ${RES_START} == 1 ]]
      then
         print_basename "Restarting- ${cyanf}\"all\"${reset} docker container done!"
         echo " "
      fi

      exit 0
   fi

   # Update all docker container
   if [[ ${IS_UPDATE} ]]
   then
      # Reorder bash array for stop, if shared db exists
      check_shared_db_stop

      # loop for all docker container
      for DOCKER_CONTAINER_NAME in ${ar[*]}; do
         update_dc

         if [[ $? -ne 0 ]]
         then
            RES1=1
         fi

         print_foot
         if [[ ${RES1} == 1 ]]
         then
             error_exit "'Error updating docker container'"
         fi
         print_basename "Updating docker container ${cyanf}\"${DOCKER_CONTAINER_NAME}\"${reset} done!"
         echo ""
      done
      exit 0
   fi
fi

