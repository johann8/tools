#!/bin/bash

# For debug
#set -x

##############################################################################
# Script-Name : postgresql_dump_docker.sh                              #
# Description : Script to backup the databases of a PostgreSQL.              #
#               On successful execution only a LOG file will be written.     #
#               On error while execution, a LOG file and a error message     #
#               will be send by e-mail.                                      #
#                                                                            #
##############################################################################

##############################################################################
# >>> Please edit following lines for personal settings and custom usages. ! #
##############################################################################

# CUSTOM - Script-Name.
SCRIPT_NAME='postgresql_dump_docker'
SCRIPT_VERSION='1.1'
_HOST=$(echo $(hostname) | cut -d"." -f1)

# CUSTOM - Backup-Files.
DB_USER=postgres
DB_NAMES='authentikdb'
TIMESTAMP=$(date '+%Y-%m-%d_%Hh-%Mm')
BACKUP_DIR="/mnt/nfsStorage/$(hostname -s)/databases/postgreSQL"
FILE_BACKUP=pg_dump_${POSTGRES_DB}_${TIMESTAMP}.sql
FILE_DELETE='*.tar.gz'
# Number DBs x 30 Days
# Example: 11 x 30 = 330
# Actual: 5 x 10 = 50
DB_NUMBER=1
DAYS_NUMBER=10
BACKUPFILES_DELETE=$((${DB_NUMBER} * ${DAYS_NUMBER}))
BACKUPFILES_DELETE_DB=${DAYS_NUMBER}

# CUSTOM - Mail-Recipient.
MAIL_RECIPIENT='user@myfirma.de'

# CUSTOM - Status-Mail [Y|N].
MAIL_STATUS='Y'

### CUSTOM - docker container name

#
### === CHANGEME ===
#
CONTAINER=$(docker container ls | grep 'authentik-postgres' | cut -d" " -f1)


##############################################################################
# >>> Normaly there is no need to change anything below this comment line. ! #
##############################################################################

# Variables.
DOCKER_COMMAND=`command -v docker`
SED_COMMAND=`command -v sed`
TAR_COMMAND=`command -v tar`
TOUCH_COMMAND=`command -v touch`
RM_COMMAND=`command -v rm`
PROG_SENDMAIL='/sbin/sendmail'
CAT_COMMAND=`command -v cat`
DATE_COMMAND=`command -v date`
MKDIR_COMMAND=`command -v mkdir`
FILE_LOCK='/tmp/'$SCRIPT_NAME'.lock'
FILE_LOG='/var/log/'$SCRIPT_NAME'.log'
FILE_LAST_LOG='/tmp/'$SCRIPT_NAME'.log'
FILE_MAIL='/tmp/'$SCRIPT_NAME'.mail'
FILE_MBOXLIST='/tmp/'$SCRIPT_NAME'.mboxlist'
VAR_HOSTNAME=`hostname -f`
VAR_SENDER='root@'$VAR_HOSTNAME
VAR_EMAILDATE=`$DATE_COMMAND '+%a, %d.%m.%Y %H:%M:%S (%Z)'`

# Functions.
function log() {
        echo $1
        echo `$DATE_COMMAND '+%Y/%m/%d %H:%M:%S'` " INFO:" $1 >>${FILE_LAST_LOG}
}

function retval() {
if [ "$?" != "0" ]; then
        case "$?" in
        *)
                log "ERROR: Unknown error $?"
        ;;
        esac
fi
}

function movelog() {
        $CAT_COMMAND $FILE_LAST_LOG >> $FILE_LOG
        $RM_COMMAND -f $FILE_LAST_LOG
        $RM_COMMAND -f $FILE_LOCK
}

function sendmail() {
        case "$1" in
        'STATUS')
                MAIL_SUBJECT='Status execution '$SCRIPT_NAME' script.'
        ;;
        *)
                MAIL_SUBJECT='ERROR while execution '$SCRIPT_NAME' script !!!'
        ;;
        esac

$CAT_COMMAND <<MAIL >$FILE_MAIL
Subject: $MAIL_SUBJECT
Date: $VAR_EMAILDATE
From: $VAR_SENDER
To: $MAIL_RECIPIENT

MAIL

$CAT_COMMAND $FILE_LAST_LOG >> $FILE_MAIL

$PROG_SENDMAIL -f $VAR_SENDER -t $MAIL_RECIPIENT < $FILE_MAIL

$RM_COMMAND -f $FILE_MAIL

}

# Main.
log "Host: $(hostname -f)"
log ""
log "+-----------------------------------------------------------------+"
log "| Start dump of --all-databases of database server............... |"
log "+-----------------------------------------------------------------+"
log ""
log "Run script with following parameter:"
log ""
log "SCRIPT_NAME...: ${SCRIPT_NAME}.sh"
log ""
log "SCRIPT_VERSION...: ${SCRIPT_VERSION}"
log ""
log "BACKUP_DIR....: ${BACKUP_DIR}"
log ""
log "MAIL_RECIPIENT: ${MAIL_RECIPIENT}"
log "MAIL_STATUS...: ${MAIL_STATUS}"
log ""

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${DOCKER_COMMAND}" ]; then
   log "Check if command '${DOCKER_COMMAND}' was found...................[FAILED]"
   sendmail ERROR
   movelog
   exit 12
else
   log "Check if command '${DOCKER_COMMAND}' was found...................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$SED_COMMAND" ]; then
   log "Check if command '$SED_COMMAND' was found......................[FAILED]"
   sendmail ERROR
   movelog
   exit 13
else
        log "Check if command '$SED_COMMAND' was found......................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$TAR_COMMAND" ]; then
   log "Check if command '$TAR_COMMAND' was found......................[FAILED]"
   sendmail ERROR
   movelog
   exit 14
else
   log "Check if command '$TAR_COMMAND' was found......................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$TOUCH_COMMAND" ]; then
   log "Check if command '$TOUCH_COMMAND' was found....................[FAILED]"
   sendmail ERROR
   movelog
   exit 15
else
   log "Check if command '$TOUCH_COMMAND' was found....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$RM_COMMAND" ]; then
   log "Check if command '$RM_COMMAND' was found.......................[FAILED]"
   sendmail ERROR
   movelog
   exit 16
else
   log "Check if command '$RM_COMMAND' was found.......................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$CAT_COMMAND" ]; then
   log "Check if command '$CAT_COMMAND' was found......................[FAILED]"
   sendmail ERROR
   movelog
   exit 17
else
   log "Check if command '$CAT_COMMAND' was found......................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$DATE_COMMAND" ]; then
   log "Check if command '$DATE_COMMAND' was found.....................[FAILED]"
   sendmail ERROR
   movelog
   exit 18
else
   log "Check if command '$DATE_COMMAND' was found.....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$MKDIR_COMMAND" ]; then
   log "Check if command '$MKDIR_COMMAND' was found....................[FAILED]"
   sendmail ERROR
   movelog
   exit 19
else
   log "Check if command '$MKDIR_COMMAND' was found....................[  OK  ]"
fi

# Check if command (file) NOT exist OR IS empty.
if [ ! -s "$PROG_SENDMAIL" ]; then
   log "Check if command '$PROG_SENDMAIL' was found................[FAILED]"
   sendmail ERROR
   movelog
   exit 20
else
   log "Check if command '$PROG_SENDMAIL' was found................[  OK  ]"
fi

# Check if LOCK file NOT exist.
if [ ! -e "$FILE_LOCK" ]; then
   log "Check if script is NOT already runnig .....................[  OK  ]"

   $TOUCH_COMMAND $FILE_LOCK
else
   log "Check if script is NOT already runnig .....................[FAILED]"
   log ""
   log "ERROR: The script was already running, or LOCK file already exists!"
   log ""
   sendmail ERROR
   movelog
   exit 30
fi

# Check if ${BACKUP_DIR} Directory NOT exists.
if [ ! -d "${BACKUP_DIR}" ]; then
   log "Check if ${BACKUP_DIR} exists....[FAILED]"
   $MKDIR_COMMAND -p ${BACKUP_DIR}
   log "${BACKUP_DIR} was now created....[  OK  ]"
else
   log "Check if ${BACKUP_DIR} exists....[  OK  ]"
fi

# Start backup.
log ""
log "+-----------------------------------------------------------------+"
log "| Run Script ${SCRIPT_NAME}.sh .......................... |"
log "+-----------------------------------------------------------------+"
log ""

# Start backup process via postgresql dump

cd ${BACKUP_DIR}

for DB in ${DB_NAMES}; do
   log ""
   log "Dump data ..."
   log "Container ID: ${CONTAINER} ..."
   log "File: $DB-$FILE_BACKUP"
   ${DOCKER_COMMAND} exec ${CONTAINER} pg_dump -U ${DB_USER} -d ${DB} -cC > pg_dump_${DB}_${TIMESTAMP}.sql

   log ""
   log "Packaging to archive ..."
   log "Archive file: pg_dump_${DB}_${TIMESTAMP}.tar.gz
   ${TAR_COMMAND} -cvzf pg_dump_${DB}_${TIMESTAMP}.tar.gz pg_dump_${DB}_${TIMESTAMP}.sql --atime-preserve --preserve-permissions

   log ""
   COUNT_FILES=$(ls -t *.tar.gz |sort | uniq -u |wc -l)
   log "Total archived files: ${COUNT_FILES} "
   log "Delete archive files ..."

   if [ ${COUNT_FILES} -le ${BACKUPFILES_DELETE} ]; then
      log "The number of files to retain: \"${BACKUPFILES_DELETE}\" .........................[  OK  ]"
      log "SKIP: There are too few files to delete: \"${COUNT_FILES}\" ................[  OK  ]"
   else
      (ls ${FILE_DELETE} -t|head -n $BACKUPFILES_DELETE; ls ${FILE_DELETE} )|sort|uniq -u|xargs rm
      if [ "$?" != "0" ]; then
         log "Delete old archive files ${BACKUP_DIR} .....[FAILED]"
      else
         COUNT_FILES_PER_DB=$(ls -t ${FILE_DELETE} |sort | uniq -u | awk -F- '{print $1}' | grep -w ${DB} | wc -l)
         log "The number of files to retain per DB \"${BACKUPFILES_DELETE_DB}\": ...................[  OK  ]"
         log "Number of remaining archived files per DB: \"${COUNT_FILES_PER_DB}\" ........[  OK  ]"
      fi
   fi

   log ""
   log "Delete dumpfile ..."
   $RM_COMMAND pg_dump_${DB}_${TIMESTAMP}.sql
done

# Delete LOCK file.
if [ "$?" != "0" ]; then
   retval $?
   log ""
   $RM_COMMAND -f $FILE_LOCK
   sendmail ERROR
   movelog
   exit 99
else
   log ""
   log "+-----------------------------------------------------------------+"
   log "| End Script ${SCRIPT_NAME}.sh .......................... |"
   log "+-----------------------------------------------------------------+"
   log ""
fi

# Finish syncing.
log "+-----------------------------------------------------------------+"
log "| Finish......................................................... |"
log "+-----------------------------------------------------------------+"
log ""

# Status e-mail.
if [ $MAIL_STATUS = 'Y' ]; then
        sendmail STATUS
fi

# Move temporary log to permanent log
movelog

exit 0

