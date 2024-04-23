### Install `backup_lvm_snap.sh` script

```bash
# download files and set permissions
wget https://raw.githubusercontent.com/johann8/tools/master/backup_lvm/backup_lvm_snap.sh -O /usr/local/bin/backupLVS.sh
https://raw.githubusercontent.com/johann8/tools/master/backup_lvm/tar_exclude_var.txt -O /usr/local/bin/tar_exclude_var.txt
chmod 0700 /usr/local/bin/backupLVS.sh

# add crontab
crontab -e
-------
# LVM snapshot of "opt": /mnt/NAS_BareOS/docker/$(hostname -s)/lvm-snapshot
10 04  *  *  *  /usr/local/bin/backupLVS.sh > /dev/null 2>&1
-------

# show logical volumes
lvdisplay
----------------
 --- Logical volume ---
  LV Path                /dev/rl/opt
  LV Name                opt
  VG Name                rl
----------------

# Adjust vars "VOLGROUP, ORIGVOL and MAIL_RECIPIENT"
vim /usr/local/bin/backupLVS.sh
```
