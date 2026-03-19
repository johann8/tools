### Install `backup_lvm_snap.sh` script

```bash
# download files and set permissions
wget https://raw.githubusercontent.com/johann8/tools/master/backup_lvm/backup_lvm_snap.sh -O /usr/local/bin/backupLVS.sh
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

# Adjust vars "VOLGROUP, ORIGVOL, BACKUPDIR and MAIL_RECIPIENT"
vim /usr/local/bin/backupLVS.sh
```

#### Test
> [!TIP]
> - Some ISPs/DNS providers block access to our domains. You can bypass this by enabling [DNS-over-HTTPS (DoH)](https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/encrypted-dns-browsers/) in your browser. 
> - **Having trouble**? Visit our [troubleshooting page](https://massgrave.dev/troubleshoot) or raise an issue on [GitHub](https://github.com/massgravel/Microsoft-Activation-Scripts/issues).

> [!NOTE]
>
> - The `irm` command in PowerShell downloads a script from a specified URL, and the `iex` command executes it.
> - Always double-check the URL before executing the command and verify the source is trustworthy when manually downloading files.
> - Be cautious of third parties spreading malware disguised as MAS by altering the URL in the PowerShell command.

