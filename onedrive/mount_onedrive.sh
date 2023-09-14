#!/bin/bash
# set -x
# Mount onedrive remote at ${MOUNT_PATH}in background

### === Set varables ===
RCLONE=$(command -v rclone)
MOUNT_PATH=/mnt/OneDrive
RCLONE_TARGET="onedrive:Backup"

### ==== Main script ===
if [ -d ${MOUNT_PATH} ]; then
   echo "INFO: Mount path \"${MOUNT_PATH}\" exists."
else
   echo "INFO: Mount path \"${MOUNT_PATH}\" does not exist."
   echo -e "INFO: Mount path \"${MOUNT_PATH}\" is created... "
   mkdir -p ${MOUNT_PATH}
   echo [DONE]
fi

echo "INFO: OneDrive is connected...   "
${RCLONE} --vfs-cache-mode writes mount ${RCLONE_TARGET} ${MOUNT_PATH} --daemon

if [ $? -eq 0 ]; then
   echo "INFO: OneDrive was attached."
else
   echo "ERROR: OneDrive could not be attached."
fi
