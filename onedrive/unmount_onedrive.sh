#!/bin/bash
# set -x

### === Set varables ===
FUSERMOUNT=$(command -v fusermount3)
MOUNT_PATH=/mnt/OneDrive

### ==== Main script ===
# Unmount the rclone mounted onedrive at ${MOUNT_PATH}
df -hT |grep onedrive
if [ $? -eq 0 ]; then
   echo "INFO: OneDrive attached."
   echo "INFO: OneDrive is disconnected... "
   ${FUSERMOUNT} -uz ${MOUNT_PATH}   

   #  
   if [ $? -eq 0 ]; then
      echo "INFO: OneDrive was disconnected."
   else
      echo "ERROR: OneDrive could not be disconnected."
      exit 0
   fi  
else
   echo "ERROR: OneDrive could not be attached."
fi
