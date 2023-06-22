#!/bin/bash
#
# set -x

# Usage: backup.sh backup|restore [filename]
# - filename: backup.tar.xz
# Environment variables:
# - optional: TAR_OPTS

#
### === Set Variables ===
#

# CUSTOM - script
SCRIPT_NAME="backupDCV.sh"         # DCV - docker container volume
BASENAME=${SCRIPT_NAME}
SCRIPT_VERSION="0.1.35"

# CUSTOM vars - define colors
esc=""
bluef="${esc}[34m"; redf="${esc}[31m"; yellowf="${esc}[33m"; greenf="${esc}[32m"; cyanf="${esc}[36m"; pinkf="${esc}[35m"; xxxf="${esc}[1;32m"
boldon="${esc}[1m"; boldoff="${esc}[22m"
reset="${esc}[0m"

# CUSTOM - var FILE
FILE="backup.tzst"
if [ $# -eq 2 ]; then 
   FILE="$2"
fi
FILE="/backup/${FILE}"
FILE_EXTENSION=$(echo ${FILE##*.})


#
### === Functions ===
#

print_basename() {
   echo -e "${pinkf}${BASENAME}:${reset} $1"
}


#
### === Main script ===
#

if [ "$1" = "backup" ]; then
   # Skip the three host configuration entries always setup by Docker and 4th which is /backup provided by this image.
   VOLUMES=$(cat /proc/mounts | \
            grep -oP "/dev/[^ ]+ \K(/[^ ]+)" | \
            grep -v "/backup" | \
            grep -v "/etc/resolv.conf" | \
            grep -v "/etc/hostname" | \
            grep -v "/etc/hosts" | \
            tr '\n' ' ')

   if [ -z "${VOLUMES}" ]; then
      print_basename "No volumes were detected."
      exit 1
   fi

   print_basename "Volumes detected: ${cyanf}\"${VOLUMES}\"${reset}"
   print_basename "Creating archive..."

   case "$2" in
     *.tzst) # COMPRESS=zstd
             tar -I 'zstd -15 -T0' -cf "${FILE}" ${TAR_OPTS} --one-file-system ${VOLUMES}  > /dev/null 2>&1
             ;;
      *.zst) # COMPRESS=zstd
             tar -I 'zstd -15 -T0' -cf "${FILE}" ${TAR_OPTS} --one-file-system ${VOLUMES}  > /dev/null 2>&1
             ;;
     *.zstd) # COMPRESS=zstd
             tar -I 'zstd -15 -T0' -cf "${FILE}" ${TAR_OPTS} --one-file-system ${VOLUMES}  > /dev/null 2>&1
             ;;
      *.tgz) # COMPRESS=gzip
             tar -czf "${FILE}" ${TAR_OPTS} --one-file-system ${VOLUMES} > /dev/null 2>&1
             ;;
       *.gz) # COMPRESS=gzip
             tar -czf "${FILE}" ${TAR_OPTS} --one-file-system ${VOLUMES} > /dev/null 2>&1
             ;;
     *.tbz2) # COMPRESS=bzip2
             tar -cjf "${FILE}" ${TAR_OPTS} --one-file-system ${VOLUMES} > /dev/null 2>&1
             ;;
      *.bz2) # COMPRESS=bzip2
             tar -cjf "${FILE}" ${TAR_OPTS} --one-file-system ${VOLUMES} > /dev/null 2>&1
             ;;
          *) print_basename "Unknown file extension: ${cyanf}\"${FILE_EXTENSION}\"${reset}"
             ;;
   esac

   print_basename "Written to ${cyanf}\"${FILE}\"${reset}"

elif [ "$1" = "restore" ]; then
   print_basename "Restoring from ${cyanf}\"${FILE}\"${reset}"

   case "${2}" in
     *.tzst) # COMPRESS=zstd
             tar -xf "${FILE}" -I 'zstd' --preserve-permissions ${TAR_OPTS} -C /  > /dev/null 2>&1
             ;;
      *.zst) # COMPRESS=zstd
             tar -xf "${FILE}" -I 'zstd' --preserve-permissions ${TAR_OPTS} -C /  > /dev/null 2>&1
             ;;
     *.zstd) # COMPRESS=zstd
             tar -xf "${FILE}" -I 'zstd' --preserve-permissions ${TAR_OPTS} -C /  > /dev/null 2>&1
             ;;
      *.tgz) # COMPRESS=gzip
             tar -xzf "${FILE}" --preserve-permissions ${TAR_OPTS} -C / > /dev/null 2>&1
             ;;
       *.gz) # COMPRESS=gzip
             tar -xzf "${FILE}" --preserve-permissions ${TAR_OPTS} -C / > /dev/null 2>&1
             ;;
     *.tbz2) # COMPRESS=bzip2
             tar -xjf "${FILE}" --preserve-permissions ${TAR_OPTS} -C / > /dev/null 2>&1
             ;;
      *.bz2) # COMPRESS=bzip2
             tar -xjf "${FILE}" --preserve-permissions ${TAR_OPTS} -C / > /dev/null 2>&1
             ;;
          *) print_basename "Unknown file extension: ${cyanf}\"${FILE_EXTENSION}\"${reset}"
             ;;
   esac
fi
