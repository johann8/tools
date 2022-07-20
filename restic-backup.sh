#!/usr/bin/env bash
#
# bu: Backup data to repository.
#
# Type 'bu --help' for help on actions and options.
#
# Configuration of 'bu' is done via environmental variables which can be set by user
# in a particular session or saved to a file and read by 'bu'.
#
# Examples of backup configuration files:
#
#   S3 remote repository:
#
#       export AWS_ACCESS_KEY_ID="your-Wasabi-Access-Key”
#       export AWS_SECRET_ACCESS_KEY="your-Wasabi-Secret-Key”
#       export RESTIC_REPOSITORY="s3:https://s3.wasabisys.com/repo-name"
#       export RESTIC_PASSWORD="speakfriendandenter"
#       export BACKUP_PATHS="$HOME/projects"
#       export RETENTION_POLICY="--keep-daily=31 --keep-monthly=12 --keep-yearly=3"
#       export SNAPSHOT_TITLE="primary_work"
#
#   B2 remote repository:
#
#       export B2_ACCOUNT_ID="your-b2-account-id"
#       export B2_ACCOUNT_KEY="your-b2-account-key"
#       export RESTIC_REPOSITORY="b2:repo-name"
#       export RESTIC_PASSWORD="speakfriendandenter"
#       export BACKUP_PATHS="$HOME/projects"
#       export RETENTION_POLICY="--keep-daily=31 --keep-monthly=12 --keep-yearly=3"
#       export SNAPSHOT_TITLE="primary_work"
#
#   Filesystem repository:
#
#       export RESTIC_REPOSITORY="/media/peregrine/STORAGE1/backups"
#       export RESTIC_PASSWORD="speakfriendandenter"
#       export BACKUP_PATHS="$HOME/projects"
#       export RETENTION_POLICY="--keep-daily=31 --keep-monthly=12 --keep-yearly=3"
#       export SNAPSHOT_TITLE="primary_work"
#
# Examples of usage:
#
#   $ bu -c primary-backup.conf init            # create a new repository
#   $ bu -c primary-backup.conf backup purge    # backup and cleanup
#   $ bu -c primary-backup.conf list            # list snapshots
#   $ bu -c primary-backup.conf check           # check repository integrity
#
# Adapted from:
#
#   https://github.com/erikw/restic-systemd-automatic-backup
#
# Copyright (c) 2018 Jeet Sukumaran
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
###
#
# ======================================================================== #
#                                                                          #
# Adpted from:                                                             #
#                                                                          #
#   https://gist.github.com/jeetsukumaran/61ff0033360174cda99ed3b444ba6dac #
#                                                                          #
# Added the possibility to backup to a rest server:                        #
#                                                                          #
#   https://github.com/restic/rest-server                                  #
#                                                                          #
# Modified by Johann Hahn on 05.07.2022                                    #
#                                                                          #
# ======================================================================== #

# ================================================================================================ #
#                                                                                                  #
# Example of backup configuration file rest server repository:                                     #
#                                                                                                  #
# export RESTIC_REPOSITORY="rest:https://UserName:PassWord@rserver.int.anwalt4u.net:8000/my-repo"  #
# export RESTIC_PASSWORD="J+0z1zp246zusvgWpQwC9sTC5bGkUoR6xQVTnfimiw8="                            #
# export CA_CERT="/path/to/public_key/rserver/data/public_key"                                     #
# export BACKUP_INCLUDES="/path/to/file/backup.files"                                              #
# export BACKUP_EXCLUDES="/path/to/file/exclude.files"                                             #
# export RETENTION_POLICY="--keep-daily 5 --keep-weekly 1 --keep-monthly 6 --keep-yearly 1"        #
# export SNAPSHOT_TITLE="primary_work"                                                             #
#                                                                                                  #
# ================================================================================================ #

##############################################################################
# >>>>>>>>>>>>>>>>>>>>>>> Set or change variables!!! <<<<<<<<<<<<<<<<<<<<<<< #
##############################################################################

# debug enable
#set -x

# Set script version
SCRIPT_VERSION="0.2.7"

# Set path for restic action "restore"
#RESTORE_PATH="${RESTORE_PATH:-/tmp/restore}" 

# set path to config
#CONFIG_PATH="/root/restic/.docker01-env"

# Enable Rest Server: true or false
ENABLE_REST_SERVER=true

# set Path to restic
RESTIC_PATH="${RESTIC_PATH:-/usr/local/bin/restic}"

# set
RETENTION_POLICY="${RETENTION_POLICY:-"--keep-daily 30 --keep-weekly 24 --keep-monthly 6"}"

##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

# script name
basename="${0##*/}"

# Log start time
START_TIME="$(date +"%Y-%m-%d %H:%M:%S")"
echo "-bu: Starting on ${HOSTNAME} at: $START_TIME"

# Exit on failure, pipe failure
# set -e -o pipefail

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole
# cgroup and all it's subprocesses. However if we kill this script ourselves,
# we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "-bu: In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	$RESTIC_PATH unlock
}
trap exit_hook INT TERM

error_exit() {
    if [[ ! -z $1 ]]
    then
        echo "-bu: $1 returned non-zero exit code: terminating"
    fi
	# jobs -p | xargs kill
    # $RESTIC_PATH unlock 2>/dev/null 1>/dev/null
    exit 1
}

ACTION_CMDS="init backup restore forget snapshots unlock rebuild prune check mount stats ls find list"
function join_by { local IFS="$1"; shift; echo "$*"; }
show_help() {
    echo "usage: bu [-c CONFIGURATION-FILE] [OPTIONS] ($(join_by \| $ACTION_CMDS))"
    echo ""
    echo "Backup data to a repository."
    echo ""
    echo "Actions:"
    echo ""
    echo "  init                     Initialize (create) the repository."
    echo "  backup                   Backup data to repository."
    echo "  forget                   Apply dereferencing policy ('forget') and prune."
    echo "                           The quotes For forget option  must be set."
    echo "                           Example: forget  -f|--forget-options \"--dry-run"\"
    echo "  snapshots                List all snapshots in repository."
    echo "  check                    Check the repository."
    echo "  unlock                   Unlock a repository in a stale locked state."
    echo "  rebuild                  Rebuild the repository index."
    echo "  prune                    Prune the repository."
    echo "  mount                    Mount the repository to any folder e.g. \"/tmp/mountPoint\""
    echo "                           The command line is redirected to linux command \"screen\". Run \"screen -r restic\" and press enter."
    echo "  stats                    Scan the repository and show basic statistics."
    echo "  find                     Find a file, a directory or restic IDs."
    echo '                           Example: find -n|--name file.conf'
    echo "  ls                       List files in a snapshot." 
    echo '                           Example: ls -sid|--snapshot-id 22bsg63' 
    echo "  restore                  Extract the data from a snapshot."
    echo '                           Example: restore -sid|--snapshot-id -t|--target /myfolder'
    echo "  diff                     Show differences between two snapshots."
    echo "                           The quotation marks are necessary!!!"
    echo "                           Example: diff -d|--difference \"snapshotID_1 snapshotID_2\""
    echo "  list                     List objects in the repository"
    echo "                           Example: list -l|--list snapshots"
    echo ""
    echo "Options:"
    echo ""
    echo "  -h, --help               Show help and exit."
    echo "  -c, --config             Path to file with configuration environmental"
    echo "                           variables declared for export. If not specified,"
    echo "                           then environmental variables must be externally"
    echo "                           set prior to invoking program."
    echo "  -v, --version            Show script version and exit." 
    echo "  --ignore-missing         On backup, ignore missing backup paths."
    echo "  --dry-run                Do not actually do anything: just run through"
    echo "                           commands."
    echo "  -i, --include            Include Files or Folder to restore"
    echo "  -e, --exclude            Exclude Files or Folder from restore"
    echo "  -n, --name               Name of File or Folder to find in a snapshot"
    echo "  -m, -mp, --mountpath     Path to mount snapschot"
    echo "  -p, --path               "
    echo "  -id, -sid --snapshot-id  The name of snapshot ID"
    echo "  -t, --target             Path for the restore of snapshot"
    echo "  -d, --difference         The names of two snapshots that you want to compare. The quotes must be set."
    echo "  -l, --list               List objects in the repository: [blobs|packs|index|snapshots|keys|locks]"
    echo "  -f, --forget-options     Add forget additional options"
    echo ""
    echo ""
    echo "Example1:  ${basename} --config /root/restic/.docker01-env init"
    echo "Example2:  ${basename} --version"
    echo "Example3:  ${basename} --help"
    echo "Example4:  ${basename} --config /root/restic/.docker01-env backup"
    echo "Example5:  ${basename} --config /root/restic/.docker01-env mount --mountpath \"/pfad/to/mount/point\""
    echo "Example6:  ${basename} --config /root/restic/.docker01-env stats"
    echo "Example7:  ${basename} --config /root/restic/.docker01-env ls"
    echo "Example8:  ${basename} --config /root/restic/.docker01-env ls -sid ff4eef11 | grep /myfolder"
    echo "Example9:  ${basename} --config /root/restic/.docker01-env find -n \"ssh\""
    echo "Example10: ${basename} --config /root/restic/.docker01-env diff -d \"latest f836c4d8\""
    echo "Example11: ${basename} --config /root/restic/.docker01-env list -l snapshots"
    #echo "Example12: ${basename} --config /root/restic/.docker01-env forget  -f \"--group-by ' '"\"
    echo "Example13: ${basename} --config /root/restic/.docker01-env forget  -f \"--host myhost.domain.com --dry-run\""
    echo "Example14: ${basename} --config /root/restic/.docker01-env forget  -f \"--group-by host,[paths],[tags] -dry-run\""
    echo "Example15: ${basename} --config /root/restic/.docker01-env forget  -f \"--dry-run --group-by host,[paths],[tags]\""
    echo ""
    echo "### =======  Examples for restore ======="
    echo "*** Restore any snapshot ID ***"
    echo "Example1: ${basename} --config /root/restic/.docker01-env restore -sid ff4eef11 --target /path/to/folder"
    echo ""
    echo "*** Restore latest snapshot ID ***"
    echo "Example2: ${basename} --config /root/restic/.docker01-env restore -id latest --target /path/to/folder"
    echo ""
    echo "*** Restore only folder \"etc\" or \"/etc\" of any snapshot ***"
    echo "Example3: ${basename} --config /root/restic/.docker01-env restore -sid ef2cf514 --target /tmp/restore --include \"etc\""
    echo ""
    echo "*** Restore all files except for folder \"/etc\" of latest snapshot ***"
    echo "Example4: ${basename} --config /root/restic/.docker01-env restore -sid latest --target /tmp/restore --exclude \"etc\"" 
    echo ""
    echo "*** Restore all files in the path \"/etc\" of latest snapshot ***"
    echo "Example5: ${basename} --config /root/restic/.docker01-env restore -id latest -t /tmp/restore/ --path /etc"
    echo ""
}

# Variables to be read/populated based on command line
BACKUP_CONFIGURATION_PATH=""
IS_INIT=""
IS_UNLOCK=""
IS_BACKUP=""
IS_FORGET_AND_PRUNE=""
IS_CHECK=""
IS_REBUILD=""
IS_PRUNE_ONLY=""
IS_LIST=""
IS_DRY_RUN=""
IS_IGNORE_MISSING=""
IS_SNAPSHOTS=""
IS_MOUNT=""
IS_MOUNT_PATH=""
MOUNT_PATH=""
IS_RESTORE=""
IS_FIND=""
IS_STATS=""
IS_INCLUDE=""
INCLUDE_PATH=""
IS_EXCLUDE=""
EXCLUDE_PATH=""
SNAPSHOT_ID=""
RESTORE_PATH=""
IS_PATH=""
__PATH=""
IS_NAME=""
__NAME=""
SNAPSHOTS_IDS=""
IS_DIFF=""
IS_LIST=""
IS_INDEX=""
INDEX_FLAG=""
IS_FORGET=""
FORGET_OPTIONS=""

# Process command line arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -c|--config)
            shift
            BACKUP_CONFIGURATION_PATH=$1
            shift
            ;;
        -h|--help)
            show_help
            exit
            ;;
        -v|--version)
            echo "-bu: Will show script version."
            echo "-bu: Script version is: ${SCRIPT_VERSION}"
            exit
            ;;
        --dry-run)
            IS_DRY_RUN=1
            shift
            ;;
        --ignore-missing)
            IS_IGNORE_MISSING=1
            shift
            ;;
        --ignore-missing)
            IS_IGNORE_MISSING=1
            shift
            ;;
        -i|--include)
            IS_INCLUDE=1
            shift
            INCLUDE_PATH=$1
            shift
            ;;
        -e|--exclude)
            IS_EXCLUDE=1
            shift
            EXCLUDE_PATH=$1
            shift
            ;;
        -n|--name)
            IS_NAME=1
            shift
            __NAME=$1
            shift
            ;;
        -m|-mp|--mountpath)
            IS_MOUNT_PATH=1
            shift
            MOUNT_PATH=$1
            shift 
           ;;
        --path)
            IS_PATH=1
            shift
            __PATH=$1
            shift
            ;;
        -id|-sid|--snapshot-id)
            shift
            SNAPSHOT_ID=$1
            shift
            ;;
        -t|--target)
            shift
            RESTORE_PATH=$1
            shift
            ;;  
        -d|--difference)
            shift
            SNAPSHOTS_IDS=$1
            shift
            ;;
        -l|--list)
            IS_INDEX=1
            shift
            INDEX_FLAG=$1
            shift
           ;;
        -f|--forget-options)
            IS_FORGET=1
            shift
            FORGET_OPTIONS=$1
            shift
           ;;
        -*|--*)
            echo "-bu: Unrecognized option: '$key'"
            echo "-bu: See 'bu --help' for supported 'bu' options."
            exit
        ;;
        *)    # unknown option
            POSITIONAL_ARGS+=("$key") # save it in an array for later
            shift # past argument
        ;;
    esac
done
# set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# show output of script versin
echo "-bu: Script version is: ${SCRIPT_VERSION}"

# Path to restic
if [[ $IS_DRY_RUN ]]
then
    RESTIC_PATH="echo restic"
    echo "-bu: Running in dry run mode"
else
    # RESTIC_PATH=restic
    # RESTIC_PATH="echo restic"
    echo "-bu: restic path is: $RESTIC_PATH"
fi

# Expect to get an action command as a positional argument.
if [[ -z $POSITIONAL_ARGS ]]
then
    echo "-bu: Please specify an action: $(join_by , $ACTION_CMDS)"
    exit 1
fi

# Read configuration path
if [[ -n "$BACKUP_CONFIGURATION_PATH" ]]
then
    if [[ -f "$BACKUP_CONFIGURATION_PATH" ]]
    then
        echo "-bu: Reading backup configuration file: '$BACKUP_CONFIGURATION_PATH'"
        source $BACKUP_CONFIGURATION_PATH
        if [[ $? -ne 0 ]]
        then
            echo "-bu: ERROR: failed to read configuration file."
            exit 1
        fi
    else
        echo "-bu: ERROR: Backup configuration file not found: '$BACKUP_CONFIGURATION_PATH'"
        exit 1
    fi
fi

# Check if at least the repository destination is defined
if [[ -z $RESTIC_REPOSITORY ]]
then
    echo "-bu: Environmental variable \$RESTIC_REPOSITORY specifying path to repository not defined"
    exit 1
fi

# Check if at least the repository destination is defined
# JH changed on 05.07.2022
if [[ ! ${ENABLE_REST_SERVER} ]]
then
    if [[ -z $BACKUP_PATHS ]]
    then
        echo "-bu: Environmental variable \"$BACKUP_PATHS\" specifying path to back up is not defined"
        exit 1
    fi
fi

# Iterate over positional arguments
for POS_ARG in ${POSITIONAL_ARGS[@]}
do
    case $POS_ARG in
        init)
            shift
            IS_INIT=1
            echo "-bu: Will initialize new repository at: '$RESTIC_REPOSITORY'"
            ;;
        unlock)
            shift
            IS_UNLOCK=1
            echo "-bu: Will unlock repository at: '$RESTIC_REPOSITORY'"
            ;;
        backup)
            shift
            IS_BACKUP=1
            echo "-bu: Will back up to repository at: '$RESTIC_REPOSITORY'"
            ;;
        forget)
            shift
            IS_FORGET_AND_PRUNE=1
            echo "-bu: Will dereference and prune repository at: '$RESTIC_REPOSITORY'"
            ;;
        snapshots)
            shift
            IS_SNAPSHOTS=1
            echo "-bu: Will list snapshots in repository at: '$RESTIC_REPOSITORY'"
            ;;
        rebuild)
            shift
            IS_REBUILD=1
            echo "-bu: Will rebuild index of repository at: '$RESTIC_REPOSITORY'"
            ;;
        prune)
            shift
            IS_PRUNE_ONLY=1
            echo "-bu: Will prune repository at: '$RESTIC_REPOSITORY'"
            ;;
        check)
            shift
            IS_CHECK=1
            echo "-bu: Will check repository at: '$RESTIC_REPOSITORY'"
            ;;
        mount)
            shift
            IS_MOUNT=1
            echo "-bu: Will mount repository at: '$RESTIC_REPOSITORY'"
            ;;
        find)
            shift
            IS_FIND=1
            echo "-bu: Will find a file, a directory or restic IDs from repository at: '$RESTIC_REPOSITORY'"
            ;;
        restore)
            shift
            IS_RESTORE=1
            if [[ -n ${RESTORE_PATH} ]]
            then
                echo "-bu: Will restore snapshot ID \"${SNAPSHOT_ID}\" from repository at: '$RESTIC_REPOSITORY'"
            else
                echo "-bu: You have not entered target."
                error_exit "'restic restore a snapshot'"
            fi
            ;; 
       stats)
            shift
            IS_STATS=1
            echo "-bu: Will show basic statistics from repository at: '$RESTIC_REPOSITORY'"
            ;;
        ls)
            shift
            IS_LS=1
            if [[ -n ${SNAPSHOT_ID} ]]
            then
                echo "-bu: Will list files in a snapshot from repository at: '$RESTIC_REPOSITORY'"
            else 
                echo "-bu: You have not entered a snapshot ID."
                error_exit "'restic list files'" 
            fi
            ;;
       diff)
            shift
            IS_DIFF=1
            echo "-bu: Will show differences between two snapshots from repository at: '$RESTIC_REPOSITORY'"
            ;; 
       list)
            shift
            IS_LIST=1
            echo "-bu: Will list objects in the repository at: '$RESTIC_REPOSITORY'"
            ;;
       *)
            echo "-bu: Unrecognized action command: '$POS_ARG'"
            echo "-bu: See 'bu --help' for supported 'bu' options."
            exit
        ;;
    esac
done

BACKUP_TAG="$(echo "$START_TIME" | sed -e 's/://g' | sed -e 's/ /_/g')_${HOSTNAME}"
if [[ -n "$SNAPSHOT_TITLE" ]]
then
    BACKUP_TAG="${BACKUP_TAG}_${SNAPSHOT_TITLE}"
fi
if [[ -z $BACKUP_TAG ]]
then
    echo "-bu: Empty backup tag generated"
    exit 1
fi
echo "-bu: Destination repository: '$RESTIC_REPOSITORY'"

# NOTE start all commands in background and wait for them to finish.
# Reason: bash ignores any signals while child process is executing and thus my trap exit hook is not triggered.
# However if put in subprocesses, wait(1) waits until the process finishes OR signal is received.
# Reference: https://unix.stackexchange.com/questions/146756/forward-sigterm-to-child-in-bash

if [[ $IS_INIT ]]
then
    echo "-bu: Repository initialization starting"
    $RESTIC_PATH init &
    wait $!
    echo "-bu: Repository initialization done"
fi

if [[ $IS_UNLOCK ]]
then
    echo "-bu: Unlocking repository"
    $RESTIC_PATH unlock &
    wait $!
fi

#
### JH changed on 05.07.2022
# 

if [[  ${ENABLE_REST_SERVER} ]]
then
    # backup is true 
    if [[ $IS_BACKUP ]]
    then
        # Check if at least one backup path is given
        if [[ -z $BACKUP_INCLUDES ]]
        then
            echo "-bu: Backup include information not found in \$BACKUP_INCLUDES"
            exit 1
        fi
        echo "-bu: Backup starting"
        echo "-bu: Backup tag: '$BACKUP_TAG'"
        echo "-bu: Paths to be included: "
        echo -e `cat $BACKUP_INCLUDES`
        echo "-bu: Paths to be excluded: $BACKUP_EXCLUDES"
        echo -e `cat $BACKUP_EXCLUDES`
        $RESTIC_PATH backup \
            --one-file-system \
            --exclude-caches \
            --files-from $BACKUP_INCLUDES \
            --exclude-file $BACKUP_EXCLUDES \
            --tag $BACKUP_TAG &
            wait $!
        if [[ $? == 1 ]]
        then
            error_exit "'restic backup'"
        fi
        echo "-bu: Backup done"
    fi
else
    # backup is true
    if [[ $IS_BACKUP ]]
    then
        # Check if at least one backup path is given
        if [[ -z $BACKUP_PATHS ]]
        then
            echo "-bu: Backup path information not found in \$BACKUP_PATHS"
            exit 1
        fi
        echo "-bu: Backup starting"
        echo "-bu: Backup tag: '$BACKUP_TAG'"
        echo "-bu: Paths to be included:"
        PROPOSED_BACKUP_PATHS="$BACKUP_PATHS"
        BACKUP_PATHS=""
        for BACKUP_PATH in $PROPOSED_BACKUP_PATHS
        do
            if [[ -d $BACKUP_PATH ]]
            then
                echo "-bu:     '$BACKUP_PATH'"
                BACKUP_PATHS="$BACKUP_PATHS $BACKUP_PATH"
            else
                if [[ $IS_IGNORE_MISSING ]]
                then
                    echo "-bu:     '$BACKUP_PATH' [NOT FOUND]"
                else
                    echo "-bu: ABORTING DUE TO MISSING PATH: '$BACKUP_PATH'"
                    exit 1
                fi
            fi
        done
        echo "-bu: Paths to be excluded: $BACKUP_EXCLUDES"
        $RESTIC_PATH backup \
            --one-file-system \
            --tag $BACKUP_TAG \
            $BACKUP_EXCLUDES \
            $BACKUP_PATHS &
        wait $!
        if [[ $? == 1 ]]
        then
            error_exit "'restic backup'"
        fi
        echo "-bu: Backup done"
    fi
fi

if [[ $IS_FORGET_AND_PRUNE ]]
then
    #if [[ -z $RETENTION_POLICY ]]
    #then
    #    RETENTION_POLICY="--keep-daily 14 --keep-weekly 16 --keep-monthly 18 --keep-yearly 3"
    #fi
    echo "-bu: Dereferencing starting"
    echo "-bu: Retention policy: '$RETENTION_POLICY'"
    $RESTIC_PATH forget     \
        $RETENTION_POLICY   \
        ${FORGET_OPTIONS}   \
        &
    wait $!
    if [[ $? == 1 ]]
    then
        error_exit "'restic forget'"
    fi
    echo "-bu: Purging done"
fi

if [[ $IS_SNAPSHOTS ]]
then
    $RESTIC_PATH snapshots &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic list'"
    fi
fi

if [[ $IS_REBUILD ]]
then
    # Rebuild repository for errors.
    echo "-bu: Rebuilding starting"
    $RESTIC_PATH rebuild-index &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic rebuild'"
    fi
    echo "-bu: Rebuilding done"
    echo "-bu: Run 'prune' followed by 'check' to complete."
fi

if [[ $IS_PRUNE_ONLY ]]
then
    echo "-bu: Pruning starting"
    $RESTIC_PATH prune
    wait $!
    if [[ $? == 1 ]]
    then
        error_exit "'restic prune'"
    fi
    echo "-bu: Pruning done"
fi

if [[ $IS_CHECK ]]
then
    # Check repository for errors.
    echo "-bu: Checking starting"
    $RESTIC_PATH check &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic check'"
    fi
    echo "-bu: Checking done"
fi

#
### === JH added since 06.07.2022 ===
#

#  Restic action: mount
if [[ ${IS_MOUNT} ]]
then
    # check screen exists
    if ! [[ -f /usr/bin/screen ]]
    then
        echo "-bu: the package \"screen\" is not installed"
        echo "-bu: Please install the package \"screen\" first and run script again."
        exit 1
    fi

    # check mount.fuse exists
    if ! [[ -f /usr/sbin/mount.fuse ]]
    then
        echo "-bu: the package \"fuse\" is not installed."
        echo "-bu: Please install the package \"fuse\" first and run script again."
        exit 1
    fi

    # delete old screen sessions and create screen session "restic" in detached mode
    if ! ( screen -ls | grep restic > /dev/null)
    then
        screen -dmS restic
    fi

    # if note exists, then create
    if ! [[ -d ${MOUNT_PATH} ]]
    then
        mkdir -p ${MOUNT_PATH}
    fi

    # Run screen named "restic" in detached mode and passes the command to screen terminal
    screen -S restic -X stuff "source $(echo ${BACKUP_CONFIGURATION_PATH}); restic mount ${MOUNT_PATH}"

    if [[ $? == 1  ]]
    then
        error_exit "'restic mount'"
    fi

    echo "-bu: Mounting done"
    echo ""
    echo "-bu: Please run \"screen -r restic\" to enter \"screen\" terminal and after that press enter."
    echo "-bu: Ctrl+A+D will return you back."
    echo "-bu: Ctrl+A+D will return you back."
    echo "-bu: You can now browse at: \"${MOUNT_PATH}\""
fi

# Restic action: restore
if [[ ${IS_RESTORE} ]]
then
    # Extract the data from a snapshot
    echo "-bu: Restoring starting"

    if [[ ! -d ${RESTORE_PATH} ]]
    then
        echo "-bu: Creating of target \"${RESTORE_PATH}\""
        mkdir -p ${RESTORE_PATH}
    fi

    if [[ ${IS_EXCLUDE} ]]
    then
        $RESTIC_PATH restore ${SNAPSHOT_ID} --target ${RESTORE_PATH} --exclude ${EXCLUDE_PATH} --verify &
        wait $!
        if [[ $? == 1  ]]
        then
            error_exit "'restic restore'"
        fi
        echo "-bu: Restoring done"
    elif [[ ${IS_INCLUDE} ]]
    then
        $RESTIC_PATH restore ${SNAPSHOT_ID} --target ${RESTORE_PATH} --include ${INCLUDE_PATH} --verify &
        wait $!
        if [[ $? == 1  ]]
        then
            error_exit "'restic restore'"
        fi
        echo "-bu: Restoring done"
    elif [[ ${IS_PATH} ]]
    then
        $RESTIC_PATH restore ${SNAPSHOT_ID} --target ${RESTORE_PATH} --path ${__PATH} --verify &
        wait $!
        if [[ $? == 1  ]]
        then
            error_exit "'restic restore'"
        fi
        echo "-bu: Restoring done"
    else 
        $RESTIC_PATH restore ${SNAPSHOT_ID} --target ${RESTORE_PATH} --verify &
        wait $!
        if [[ $? == 1  ]]
        then
            error_exit "'restic restore'"
        fi
        echo "-bu: Restoring done"
    fi
fi

# Restic action: stats
if [[ $IS_STATS ]]
then
    # Scan the repository and show basic statistics.
    echo "-bu: Scanning starting"
    $RESTIC_PATH stats &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic scan'"
    fi
    echo "-bu: Scanning done"
fi

# Restic action: ls
if [[ $IS_LS ]]
then
    #
    #SNAPSHOT_ID=$(echo ${*: -1:1})
    #echo ${SNAPSHOT_ID}
    # List files in a snapshot.
    echo "-bu: Listing files starting"
    $RESTIC_PATH ls ${SNAPSHOT_ID} &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic listung files'"
    fi
    echo "-bu: Listing files done"
fi

# Restic action: find
if [[ $IS_FIND ]]
then
    # Find a file, a directory or restic IDs
    echo "-bu: Finding starting"
    $RESTIC_PATH find ${__NAME} &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic find'"
    fi
    echo "-bu: Finding done"
fi

# Restic action: diff
if [[ $IS_DIFF ]]
then
    # Show differences between two snapshots
    echo "-bu: Starting show difference"
    $RESTIC_PATH diff ${SNAPSHOTS_IDS} &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic diff'"
    fi
    echo "-bu: Show difference done"
fi

# Restic action: list
if [[ $IS_LIST ]]
then
    # List objects in the repository: [blobs|packs|index|snapshots|keys|locks]
    echo "-bu: Starting list objects"
    $RESTIC_PATH list ${INDEX_FLAG} &
    wait $!
    if [[ $? == 1  ]]
    then
        error_exit "'restic list'"
    fi
    echo "-bu: List object \"${INDEX_FLAG}\" done"
fi


END_TIME="$(date --rfc-3339=seconds)"
echo "-bu: Exiting normally at: $END_TIME"
