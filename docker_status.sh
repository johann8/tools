#!/usr/bin/env bash
#

# debug enable
#set -x

# CUSTOM VARs
SCRIPT_NAME="docker_container_status.sh"
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.0.7"
TIMESTAMP="$(date +%Y%m%d-%Hh%Mm)"
_DATUM="$(date '+%Y-%m-%d %Hh:%Mm:%Ss')"
SCRIPT_START_TIME=$SECONDS                                # Script start time
# CUSTOM - logs
FILE_LAST_LOG='/tmp/'${SCRIPT_NAME}'.log'                 # Script log file

# set Path to docker-compose
# DOCKER_COMPOSE_PATH=$(command -v docker-compose)        # echo ${DOCKER_COMPOSE_PATH}
# DOCKER_COMPOSE_DIR=${DOCKER_COMPOSE_PATH%/*}            # echo ${DOCKER_COMPOSE_DIR}


##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

# docker binary path
DOCKER_COMMAND=`command -v docker`

# docker version
DOCKER_COMPOSE_VERSION=$(${DOCKER_COMMAND} version | head -n 2 | grep Version | awk '{print $2}')

# docker container status = exited
CONTAINERS_EXITED=$(docker ps --format "{{.Names}}" -f status="exited" -f status="dead")

# docker container status = unhealthy
CONTAINERS_UNHEALTHY=$(docker ps --format "{{.Names}}" -f health="unhealthy")

# Set scripts ctions
ACTION_CMDS="exited healthy help version"


### Functions
# join_by
function join_by { local IFS="$1"; shift; echo "$*"; }

# show_help
show_help() {
    echo "usage: ${BASENAME} [ACTION] ($(join_by \| $ACTION_CMDS))"
    echo ""
    echo "Info: Shows the status of Docker containers."
    echo ""
    echo "Actions:"
    echo "--------"
    echo "  exited                Will show exited container and start them."
    echo "  healthy               Will show unhelthy container and start them"
    echo "  version               Will show script version."
    echo "  help                  Will show this help."
    echo ""
    echo "Example1: ${BASENAME} exited"
    echo "Example2: ${BASENAME} healthy"
    echo "Example3: ${BASENAME} -v|version"
    echo "Example4: ${BASENAME} -h|help"
    echo ""
}


#
### ===> Main script <===
#

# Process command line actions
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        exited)
            IS_EXITED=1; POSITIONAL_ARGS=${key}
            shift
            ;;
        healthy)
            IS_HEALTHY=1; POSITIONAL_ARGS=${key}
            shift
            ;;
        -h|help)
            show_help
            exit
            ;;
        -v|version)
            echo "Info: Will show script version."
            echo "Info: Script version is: ${SCRIPT_VERSION}"
            exit
            ;;
        *)
            echo "Info: Unrecognized option: '$key'"
            echo "Info: See \"${basename} -h\" for supported options."
            exit
        ;;
    esac
done

# Expect to get an action command
if [[ -z $POSITIONAL_ARGS ]]; then
   echo "Attention!: Please specify an action: $(join_by , $ACTION_CMDS)"
   exit 1
fi

#
### Main script
#
echo -e "Info: Started on \"$(hostname -f)\" at \"${_DATUM}\"" | tee /proc/1/fd/1 -a ${FILE_LAST_LOG}
echo -e "Info: Script version is: \"${SCRIPT_VERSION}\"" | tee /proc/1/fd/1 -a ${FILE_LAST_LOG}
echo -e "Info: Docker version is: \"${DOCKER_COMPOSE_VERSION}\"" | tee /proc/1/fd/1 -a ${FILE_LAST_LOG}
#echo -e " " | tee /proc/1/fd/1 -a ${FILE_LAST_LOG}


# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${DOCKER_COMMAND}" ]; then
   echo -e "Error: Command \"${DOCKER_COMMAND}\" is not available." | tee /proc/1/fd/1 -a ${FILE_LAST_LOG}
else
   echo -e "Info: Command \"${DOCKER_COMMAND}\" is available." | tee /proc/1/fd/1 -a ${FILE_LAST_LOG}
fi

# Action exited
if [[ "${IS_EXITED}" == "1" ]]; then
   #echo ""
   echo "Info: Will show exited container and start them."
   
   if [[ -z "${CONTAINERS_EXITED}" ]]; then
      echo ""
      echo "-------------------------------------" >&2
      echo "| INFO: All containers are running! |" >&2
      echo "-------------------------------------" >&2
      docker ps --format "table {{.Names}}\t{{.Status}}"
   else
      for C_ID in ${CONTAINERS_EXITED}; do

      CONTAINER_NAME=$(docker inspect --format '{{.Name}}' ${C_ID} | sed 's/^\///')
      CONTAINER_STATE_EXITED=$(docker container inspect -f '{{.State.Status}}' ${C_ID} | cut -d ' ' -f 1 | sed 's/{//')

         if [[ "${CONTAINER_STATE_EXITED}" == "running" ]]; then
            echo "INFO: Container \"${CONTAINER_NAME}\" is running."
         else
            #echo "WARNING: Container \"${CONTAINER_NAME}\" is not healthy!"
            echo ""
            echo "--------------------------------------------" >&2
            echo "| WARNING: Container \"${CONTAINER_NAME}\" is not running! |" >&2
            echo "--------------------------------------------" >&2
            WORKING_DIR=$(docker inspect --format='{{index (index .Config.Labels "com.docker.compose.project.working_dir")}}' ${C_ID})

            if [ -n "${WORKING_DIR}" ]; then
               cd "${WORKING_DIR}"
               echo "Stop and start docker stack"
               docker compose down && docker compose up -d
            else
               echo "Working DIR is unknown"
            fi
         fi
      done
   fi
fi

# Action unhelthy
if [[ "${IS_HEALTHY}" = "1" ]]; then
   echo "Info: Will show unhelthy container and start them."

   if [[ -z "${CONTAINERS_UNHEALTHY}" ]]; then
      echo ""
      echo "-------------------------------------" >&2
      echo "| INFO: All containers are healthy! |" >&2
      echo "-------------------------------------" >&2
      docker ps --format "table {{.Names}}\t{{.Status}}"
   else
      for C_ID in ${CONTAINERS_UNHEALTHY}; do

         CONTAINER_NAME=$(docker inspect --format '{{.Name}}' ${C_ID} | sed 's/^\///')
         CONTAINER_STATE_HEALTH=$(docker container inspect -f '{{.State.Health}}' ${C_ID} | cut -d ' ' -f 1 | sed 's/{//')

         if [[ "${CONTAINER_STATE_HEALTH}" == "healthy" ]]; then
            echo "INFO: Container \"${CONTAINER_NAME}\" is healthy."
         else
            #echo "WARNING: Container \"${CONTAINER_NAME}\" is not healthy!"
            echo ""
            echo "--------------------------------------------" >&2
            echo "| WARNING: Container \"${CONTAINER_NAME}\" is not healthy! |" >&2
            echo "--------------------------------------------" >&2
            WORKING_DIR=$(docker inspect --format='{{index (index .Config.Labels "com.docker.compose.project.working_dir")}}' ${C_ID})

            if [ -n "${WORKING_DIR}" ] ; then
               cd "${WORKING_DIR}"
               echo "Stop and start docker stack"
               docker compose down && docker compose up -d
            else
               echo "Working DIR is unnown"
            fi
         fi
      done
   fi
fi

END_TIME="$(date --rfc-3339=seconds)"
echo ""
echo "---------------------------------------------------------------" >&2
echo "| Info: Script exiting normally at: $END_TIME |"
echo "---------------------------------------------------------------" >&2
