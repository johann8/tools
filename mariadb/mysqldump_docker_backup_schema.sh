#!/bin/bash

# For Debug
#set -x

##############################################################################
# Script-Name : mysqldump_docker_backup_schema.sh                                     #
# Description : Script to backup the --all-databases of a MySQL/MariaDB.     #
#               On successful execution only a LOG file will be written.     #
#               On error while execution, a LOG file and a error message     #
#               will be send by e-mail.                                      #
#                                                                            #
##############################################################################

##############################################################################
#  +----------------------------------------------------------------------+  #
#  | This program is free software; you can redistribute it and/or modify |  #
#  | it.                                                                  |  #
#  +----------------------------------------------------------------------+  #
#                                                                            #
# Copyright (c) 2023 by Johann Hahn.                                         #
#                                                                            #
##############################################################################

##############################################################################
#                                H I S T O R Y                               #
##############################################################################
# -------------------------------------------------------------------------- #
# Version     : 1.01                                                         #
# Description : Add Command: docker                                          #
# -------------------------------------------------------------------------- #
#                                                                            #
# -------------------------------------------------------------------------- #
# Version     : 1.02                                                         #
# Description : Add variable CONTAINER; Changed Command: docker exec         #
# -------------------------------------------------------------------------- #
#                                                                            #
# -------------------------------------------------------------------------- #
# Version     : 1.03                                                         #
# Description : Delete some custom parameters                                #
# -------------------------------------------------------------------------- #
##############################################################################

##############################################################################
# >>> Please edit following lines for personal settings and custom usages. ! #
##############################################################################

# CUSTOM - Script-Name
SCRIPT_NAME='mysqldump_docker_backup_schema'
_HOST=$(echo $(hostname) | cut -d"." -f1)
 
# CUSTOM - Backup-Files.
DIR_BACKUP='/var/backup/'${_HOST}'/container/mysqldump_docker_backup_schema'
FILE_BACKUP=mysqldump_backup_`date '+%Y%m%d_%H%M%S'`.sql
FILE_DELETE='*.tar.gz'
BACKUPFILES_DELETE=30
 
# CUSTOM - mysqldump Parameter.
DUMP_USER='root'

# CUSTOM - Binary-Logging active. Example: ('Y'(my.cnf|log_bin=bin-log), 'N')
DUMP_BIN_LOG_ACTIVE='N'

# CUSTOM - Depends on the database engine. Example: ('Y'(MyISAM), 'N'(InnoDB))
DUMP_LOCK_ALL_TABLE='N'
 
# CUSTOM - Mail-Recipient.
MAIL_RECIPIENT='you@example.com'
 
# CUSTOM - Status-Mail [Y|N].
MAIL_STATUS='Y'

# CUSTOM - docker container name
# CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)
CONTAINER=mariadb
 
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
VAR_HOSTNAME=`uname -n`
VAR_SENDER='root@'$VAR_HOSTNAME
VAR_EMAILDATE=`$DATE_COMMAND '+%a, %d %b %Y %H:%M:%S (%Z)'`
 
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
log "| Start backup of --all-databases of database server............. |"
log "+-----------------------------------------------------------------+"
log ""
log "Run script with following parameter:"
log ""
log "SCRIPT_NAME...: $SCRIPT_NAME"
log ""
log "DIR_BACKUP....: $DIR_BACKUP"
log ""
log "MAIL_RECIPIENT: $MAIL_RECIPIENT"
log "MAIL_STATUS...: $MAIL_STATUS"
log ""
 
# Check if command (file) NOT exist OR IS empty.
if [ ! -s "${DOCKER_COMMAND}" ]; then
        log "Check if command '${DOCKER_COMMAND}' was found.................  [FAILED]"
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
 
# Check if DIR_BACKUP Directory NOT exists.
if [ ! -d "$DIR_BACKUP" ]; then
        log "Check if DIR_BACKUP exists.................................[FAILED]"
        $MKDIR_COMMAND -p $DIR_BACKUP
        log "DIR_BACKUP was now created.................................[  OK  ]"
else
        log "Check if DIR_BACKUP exists.................................[  OK  ]"
fi
 
# Start backup.
log ""
log "+-----------------------------------------------------------------+"
log "| Run backup $SCRIPT_NAME ..................... |"
log "+-----------------------------------------------------------------+"
log ""
 
# Start backup process via mysqldump.
 
cd $DIR_BACKUP
 
if [ $DUMP_LOCK_ALL_TABLE = 'Y' ]; then
        DUMP_LOCK_ALL_TABLE='--lock-all-tables'
else
        DUMP_LOCK_ALL_TABLE='--single-transaction'
fi
 
for DB in $(docker exec ${CONTAINER} sh -c 'mysql --user=root --password="${MARIADB_ROOT_PASSWORD}" --execute="show databases \G"' | grep -i Database: | grep -v -e information_schema -e performance_schema -e sys | sed 's/Database:\ //'); do
        if [ $DUMP_BIN_LOG_ACTIVE = 'Y' ]; then
                log "Dump data with bin-log data ..."
                log "File: $DB-$FILE_BACKUP"
                ${DOCKER_COMMAND} exec -e DUMP_USER=${DUMP_USER} -e DB=${DB} -e DUMP_LOCK_ALL_TABLE=${DUMP_LOCK_ALL_TABLE} ${CONTAINER} sh -c 'exec mysqldump --user="${DUMP_USER}" --password="${MARIADB_ROOT_PASSWORD}" --databases "${DB}" --flush-privileges "${DUMP_LOCK_ALL_TABLE}" --triggers --routines --events --hex-blob --quick' > $DB-$FILE_BACKUP
        else
                log "Dump data ..."
                log "File: $DB-$FILE_BACKUP"
                ${DOCKER_COMMAND} exec -e DB=${DB} -e DUMP_LOCK_ALL_TABLE=${DUMP_LOCK_ALL_TABLE} ${CONTAINER} sh -c 'exec mysqldump --user="${DUMP_USER}" --password="${MARIADB_ROOT_PASSWORD}" --databases "${DB}" --flush-privileges "${DUMP_LOCK_ALL_TABLE}" --triggers --routines --events --hex-blob --quick' > $DB-$FILE_BACKUP

        fi
 
        log ""
        log "Packaging to archive ..."
        $TAR_COMMAND -cvzf $DB-$FILE_BACKUP.tar.gz $DB-$FILE_BACKUP --atime-preserve --preserve-permissions
 
        log ""
        log "Delete archive files ..."

        #(ls $FILE_DELETE -t|head -n $BACKUPFILES_DELETE;ls $FILE_DELETE )|sort|uniq -u|xargs rm
        #if [ "$?" != "0" ]; then
        #        log "Delete old archive files $DIR_BACKUP .....[FAILED]"
        #else
        #        log "Delete old archive files $DIR_BACKUP ........[  OK  ]"
        #fi

        ### ======= Added J. Hahn ========
        #   ----------- Start ------------
        COUNT_FILES=$(ls -t *.tar.gz |sort | uniq -u |wc -l)
        if [ ${COUNT_FILES} -le ${BACKUPFILES_DELETE} ]; then
            log "The number of files to retain: \"${BACKUPFILES_DELETE}\" .......................[  OK  ]"
            log "SKIP: There are too few files to delete: \"${COUNT_FILES}\" .............[  OK  ]"
        else
            (ls $FILE_DELETE -t|head -n $BACKUPFILES_DELETE;ls $FILE_DELETE )|sort|uniq -u|xargs rm
            if [ "$?" != "0" ]; then
                log "Delete old archive files $DIR_BACKUP .....[FAILED]"
            else
                COUNT_FILES=$(ls -t *.tar.gz |sort | uniq -u |wc -l)
                log "The number of files to retain: \"${BACKUPFILES_DELETE}\" .......................[  OK  ]"
                log "Delete old archive files $DIR_BACKUP ........[  OK  ]"
            fi
        fi
        #   ------------ End ---------- 

        log ""
        log "Delete dumpfile ..."
        $RM_COMMAND $DB-$FILE_BACKUP
 
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
        log "| End backup $SCRIPT_NAME ..................... |"
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

#
### === Install backup script ===
#
wget https://raw.githubusercontent.com/johann8/tools/master/mariadb/mysqldump_docker_backup_full.sh
wget https://raw.githubusercontent.com/johann8/tools/master/mariadb/mysqldump_docker_backup_schema.sh
vi /usr/local/bin/mysqldump_docker_backup_schema.sh
chmod 0700 /usr/local/bin/mysqldump_docker_backup_schema.sh
tail -f -n2000 /var/log/mysqldump_docker_backup_schema.log

#
### === Install crontab ===
#
crontab -e
# Backup mariadb mysqldump
05  4  *  *  *  /usr/local/bin/mysqldump_docker_backup_full.sh > /dev/null 2>&1
15  4  *  *  *  /usr/local/bin/mysqldump_docker_backup_schema.sh > /dev/null 2>&1

#
### === Recovery database ===
#
mkdir /tmp/recovery
tar -xvzf /var/backup/centos7/mysqldump_docker_backup_schema/kimai-mysqldump_backup_20210908_211509.sql.tar.gz -C /tmp/recovery --atime-preserve --preserve-permissions
docker exec -i mariadb sh -c 'exec mysql -uroot -p"$MARIADB_ROOT_PASSWORD"' < /tmp/recovery/kimai-mysqldump_backup_20210908_211509.sql

#
### === Logrotate ===
#
cat > bacula-dir_template.conf << 'EOL'
/var/log/mysqldump_docker_backup_full.log /var/log/mysqldump_docker_backup_schema.log {
    weekly
    missingok
    rotate 4
    compress
}
EOL

# ls $FILE_DELETE -t|head -n $BACKUPFILES_DELETE;ls $FILE_DELETE )|sort|uniq -u|xargs rm
# cd  /var/backup/mysqldump_docker_backup_schema/ && (ls *.tar.gz -t |head -n 225; ls *.tar.gz) |sort |uniq -u


