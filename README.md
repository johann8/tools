# Tools

## Install `manageDC.sh` script 

```bash
cd /usr/local/bin
if [[ -f manageDC.sh_old ]]; then echo -n "Delete old backup"; rm -rf manageDC.sh_old; echo [ Done ]; fi
mv manageDC.sh  manageDC.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/manageDC.sh
chmod 0700 manageDC.sh 
```

## Install `delete_old_files.sh` script
The files to be deleted are located directly in the folder.

```bash
cd /usr/local/bin
if [[ -f delete_old_files.sh_old ]]; then echo -n "Delete old backup"; rm -rf delete_old_files.sh_old; echo [ Done ]; fi
mv delete_old_files.sh delete_old_files.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/delete_old_files.sh
chmod 0700 delete_old_files.sh
```

## Install `delete_old_files_subfolder.sh` script
The files to be deleted are stored in several subfolders.

```bash
cd /usr/local/bin
if [[ -f delete_old_files_subfolder.sh_old ]]; then echo -n "Delete old backup"; rm -rf delete_old_files_subfolder.sh_old; echo [ Done ]; fi
mv delete_old_files_subfolder.sh delete_old_files_subfolder.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/delete_old_files_subfolder.sh
chmod 0700 delete_old_files_subfolder.sh
```
