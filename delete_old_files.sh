#!/bin/bash
#
# Debug enable
#set -x
#
set -o errexit

#
### === Set variables ===
#

STORAGE="/var/backup/container"
FILE_DELETE="*.tar.gz"
BACKUPFILES_DELETE=20
ARRAY=($(ls ${STORAGE}))
SCRIPT_VERSION="0.1"                       # Set script version
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")     # time stamp

#
### === Run Script ===
#

echo -e "Run script at ${TIMESTAMP}"
echo "---------------------------------"
echo "Number of backup files that should remain: \"${BACKUPFILES_DELETE}\""
echo ""

if [ -d ${STORAGE} ]; then

   # Delete old files
   for i  in ${ARRAY[*]}; do

      cd ${STORAGE}/$i
      echo "Storage path: \"$(pwd)\""
      # Number of existing backup files
      COUNT_FILES=$(ls -t *.tar.gz |sort | uniq -u |wc -l)

      if [ ${COUNT_FILES} -le ${BACKUPFILES_DELETE} ]; then
         echo "SKIP: There are too few files to delete: \"${COUNT_FILES}\""
         echo ""
         continue 1
      else
         # Only for test
         COUNT_FILES_TO_DELETE=$((ls $FILE_DELETE -t|head -n ${BACKUPFILES_DELETE};ls $FILE_DELETE )| sort| uniq -u | wc -l)
         echo -n "${COUNT_FILES_TO_DELETE} old files to delete... "
         # Only for test
         #(ls $FILE_DELETE -t|head -n ${BACKUPFILES_DELETE};ls $FILE_DELETE )| sort| uniq -u | wc -l > /dev/null 2>&1
         (ls $FILE_DELETE -t|head -n ${BACKUPFILES_DELETE};ls $FILE_DELETE )| sort| uniq -u | xargs rm
         RES1=$?
         echo [ done ]
         # Check result
         if [ "$RES1" = "0" ]; then
            echo -e "\n${COUNT_FILES_TO_DELETE} old files were deleted!"
            echo "--------------------------"
         else
            echo "Error: Old files could not be deleted!"
            exit 1
         fi
      fi
   done
else
   echo "Error: The folder \"${STORAGE}\" does not exist."
   exit 1
fi