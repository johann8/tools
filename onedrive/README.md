# OneDrive mit Rclone

## Install rclone

```
# SSH-Tunnel über `cmder / cmd` erstellen
ssh -L localhost:53682:localhost:53682 -p 2222 user@mc.wassermanngruppe.de -i "C:\Users\Otto Mustermann\Documents\Putty_Key\id_ed25519"
ssh -L localhost:53682:localhost:53682 -p 2222 user@host.mydomain.de -i "C:\Users\Otto Mustermann\Documents\Putty_Key\id_ed25519"

# Auf dem Zielhost rclone installieren und konfigurieren
curl https://rclone.org/install.sh | sudo bash

rclone config
n
onedrive
31
enter   # Enter-Taste drücken
enter   # Enter-Taste drücken
1
n
y
### Ab hier kommt Microsoft Auth Abfrage. URL kopieren und im Browser eingeben, Email und Passwort eingeben
1
1
y
y
q

#
cat /root/.config/rclone/rclone.conf
```

## Einige Beispiele
```
rclone listremotes
rclone lsd onedrive:
rclone ls onedrive:
rclone ls onedrive:SharePoint_Backup

# To mount your OneDrive directory using fusemount into directory
rclone --vfs-cache-mode writes mount onedrive: /mnt/OneDrive

# If you don’t use rclone for 90 days the refresh token will expire. This will result in authorization problems. 
# This is easy to fix by running the following command to get a new token and refresh token.
rclone config reconnect remote

# Über die Option -Pv wird ein Fortschrittsanzeige angezeigt: -P - progress; -v - verbose
rclone copy -Pv /mnt/nfsStorage/docker/mc/ onedrive:Backup/someOrdner

# Ordner synchronisieren
# Verwendet man die Option --check-first , werden vor dem Kopieren oder der Synchronisierung die Dateien zwischen Quelle und Ziel abgeglichen und 
# es werden nur die Ordner und Dateien überschrieben oder gelöscht, die in der Quelle verändert wurden.
rclone sync -Pv --check-first /mnt/nfsStorage/docker/mc/ onedrive:Backup/Backup/someOrdner

# Automatische Synchronisierung über einen Cronjob einrichten: Alle 30 Min von 08:00 bis 20:00 Uhr
30 8-20 * * * rclone sync --check-first /mnt/nfsStorage/docker/mc/ onedrive:Backup/meshcentral

15 0 * * * rclone sync --check-first /mnt/nfsStorage/docker/mc/ onedrive:Backup/meshcentral
```

### Install `mount_onedrive.sh` script 

```bash
cd /usr/local/bin
if [[ -f mount_onedrive.sh_old ]]; then echo -n "Delete old script"; rm -rf mount_onedrive.sh_old; echo [ Done ]; fi
mv mount_onedrive.sh  mount_onedrive.sh_old
wget https://raw.githubusercontent.com/johann8/tools/onedrive/master/mount_onedrive.sh
chmod 0700 mount_onedrive.sh
```

### Install `umount_onedrive.sh` script

```bash
cd /usr/local/bin
if [[ -f unmount_onedrive.sh_old ]]; then echo -n "Delete old script"; rm -rf unmount_onedrive.sh_old; echo [ Done ]; fi
mv unmount_onedrive.sh  unmount_onedrive.sh_old
wget https://raw.githubusercontent.com/johann8/tools/onedrive/master/unmount_onedrive.sh
chmod 0700 unmount_onedrive.sh

```

