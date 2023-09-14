# Docker vontainer volume backup

## Backup der Docker Container Volumen


### Install `backupDCV.sh` script

```bash
cd /usr/local/bin
if [[ -f 0700 backupDCV.sh_old ]]; then echo -n "Delete old script"; rm -rf 0700 backupDCV.sh_old; echo [ Done ]; fi
mv 0700 backupDCV.sh  0700 backupDCV.sh_old
curl -L https://raw.githubusercontent.com/johann8/tools/master/docker-backup/scripts/backup_docker_volume.sh -o /usr/local/bin/backupDCV.sh
chmod 0700 backupDCV.sh
```

