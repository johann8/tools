# Tools

### Install `manageDC.sh` script 

```bash
cd /usr/local/bin
if [[ -f manageDC.sh_old ]]; then echo -n "Delete old script"; rm -rf manageDC.sh_old; echo [ Done ]; fi
mv manageDC.sh  manageDC.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/manageDC.sh
chmod 0700 manageDC.sh 
```

### Install `delete_old_files.sh` script
The files to be deleted are located directly in the folder.

```bash
cd /usr/local/bin
if [[ -f delete_old_files.sh_old ]]; then echo -n "Delete old script"; rm -rf delete_old_files.sh_old; echo [ Done ]; fi
mv delete_old_files.sh delete_old_files.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/delete_old_files.sh
chmod 0700 delete_old_files.sh
```

### Install `delete_old_files_subfolder.sh` script
The files to be deleted are stored in several subfolders.

```bash
cd /usr/local/bin
if [[ -f delete_old_files_subfolder.sh_old ]]; then echo -n "Delete old script"; rm -rf delete_old_files_subfolder.sh_old; echo [ Done ]; fi
mv delete_old_files_subfolder.sh delete_old_files_subfolder.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/delete_old_files_subfolder.sh
chmod 0700 delete_old_files_subfolder.sh
```
### Install `updateDMS.sh` script
Update docker microservice(s) image 

```bash
DMS_NAME=/opt/acme
cd ${DMS_NAME}
if [[ -f updateDMS.sh_old ]]; then echo -n "Delete old script"; rm -rf updateDMS.sh_old; echo [ Done ]; fi
mv updateDMS.sh updateDMS.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/updateDMS.sh
chmod 0700 updateDMS.sh
```

### Install `backupDMS.sh` script
Backup alle docker microservice(s) mit 

```bash
cd /usr/local/bin
if [[ -f backupDMS.sh_old ]]; then echo -n "Delete old script"; rm -rf backupDMS.sh_old; echo [ Done ]; fi
mv backupDMS.sh backupDMS.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/backupDMS.sh
chmod 0700 backupDMS.sh
```

### Install `restic-backup.sh` script
Backup alle docker microservice(s) mit

```bash
cd /usr/local/bin
if [[ -f restic-backup.sh_old ]]; then echo -n "Delete old script"; rm -rf restic-backup.sh_old; echo [ Done ]; fi
mv restic-backup.sh restic-backup.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/restic-backup.sh
chmod 0700 restic-backup.sh
```

