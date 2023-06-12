#!/bin/bash
#
# Debug enable
#set -x
#
set -o errexit

#
### === Set variables ===
#

STORAGE="/opt/meshcentral/meshc-backup"
FILE_DELETE="*.zip"
BACKUPFILES_DELETE=14
SCRIPT_VERSION="0.3"                       # Set script version
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")     # time stamp

#
### === Run Script ===
#
echo -e "Host: $(hostname -f)"
echo -e "Script version: ${SCRIPT_VERSION}"
echo -e "Run script at ${TIMESTAMP}"
echo "---------------------------------"
echo "Number of backup files that should remain: \"${BACKUPFILES_DELETE}\""
echo ""

# Delete files direkt in folder
# Run: delete old files
if [ -d ${STORAGE} ]; then
   # Delete old files
   cd ${STORAGE}
   echo "Storage path: \"$(pwd)\""
   # Number of existing backup files
   COUNT_FILES=$(ls -t ${FILE_DELETE} |sort | uniq -u |wc -l)

   if [ ${COUNT_FILES} -le ${BACKUPFILES_DELETE} ]; then
      echo "SKIP: There are too few files to delete: \"${COUNT_FILES}\""
      echo ""
   else
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
else
   echo "Error: The folder \"${STORAGE}\" does not exist."
   exit 1
fi
