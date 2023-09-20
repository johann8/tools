<h1 align="center">Festplattenpartitionierung nachträglich ändern</h1>

Manchmal ist es notwendig die Festplattenpartitionierung zu ändern, um so etwa neue Partitionen hinzufügen zu können beziehungsweise nach einem VPS- bzw. VDS-Upgrade die Partition zu erweitern.

- Starten den VPS / VDS in das Rescuesystem, das kann man ganz bequem aus dem Kundenlogin  heraus machen
- Verbindung mittels VNC herstellen
- Sich mit den Zugangsdaten für den Benutzer `root` anmelden
- Grafische Oberfläche mit dem Befehl `startxfce4` starten
- Terminal starten und `gparted` eingeben
- Partitionen anpassen
- Rebooten

## Als Beispiel die `root` Partition verkleinen und danach eine LVM Partition anlegen, `swap` und `opt` einrichten

- Partitionlayout anzeigen lassen
```
parted -a optimal /dev/sda
----------------------------
(parted) print free
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 215GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
        1024B   1049kB  1048kB           Free Space
 1      1049kB  1050MB  1049MB  primary  ext4         boot
 2      1050MB  193GB   192GB   primary  ext4
        193GB   215GB   21.5GB           Free Space
```

- partition erstellen
```
(parted) mkpart primary ext4
Start? 193GB
End? 215GB
(parted) print free
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 215GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
        1024B   1049kB  1048kB           Free Space
 1      1049kB  1050MB  1049MB  primary  ext4         boot
 2      1050MB  193GB   192GB   primary  ext4
 3      193GB   215GB   21.5GB  primary  ext4         lba
 
(parted) set 3 lvm on

(parted) print free
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 215GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
        1024B   1049kB  1048kB           Free Space
 1      1049kB  1050MB  1049MB  primary  ext4         boot
 2      1050MB  193GB   192GB   primary  ext4
 3      193GB   215GB   21.5GB  primary  ext4         lvm, lba

(parted) set 3 lba off

(parted) print free
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 215GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type     File system  Flags
        1024B   1049kB  1048kB           Free Space
 1      1049kB  1050MB  1049MB  primary  ext4         boot
 2      1050MB  193GB   192GB   primary  ext4
 3      193GB   215GB   21.5GB  primary  ext4         lvm
```

- Alle Partitionen auflisten
```
lsblk
-----
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0  200G  0 disk
├─sda1   8:1    0 1000M  0 part /boot
├─sda2   8:2    0  179G  0 part /
└─sda3   8:3    0   20G  0 part
```

- Die Partition `sda3` für LVM als Phyisical Volume (PV) vorbereiten, wobei -ff = force und -y=alles mit `Ja` beantworten bedeutet, metadatasize is LVM2 default mit 512Byte:
```
pvcreate -y -ff /dev/sda3
-------------------------
  Physical volume "/dev/sda3" successfully created
```

- Status anzeigen

```
pvs
pvdisplay
```

- Die Volume Group (VG) mit dem Namen `rl` erstellen

```
vgcreate rl /dev/sda3
```

- Status anzeigen

```pvdisplay
vgdisplay
```

- LV `swap` mit der Größe 2GB erstellen

```
lvcreate -L 2048MB -n swap rl
```

- LV `opt` mit der Größe 10GB erstellen
```
lvcreate -L 10240MB -n opt rl
```

- Erstellen swap FS auf /dev/rl/swap
```
mkswap /dev/rl/swap
```

- Erstellen ext4 auf /dev/rl/opt
```
mkfs.ext4 /dev/rl/opt
```

- Alle Partitionen auflisten
```
lsblk
-----
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0  200G  0 disk
├─sda1        8:1    0 1000M  0 part /boot
├─sda2        8:2    0  179G  0 part /
└─sda3        8:3    0   20G  0 part
  ├─rl-swap 253:0    0    2G  0 lvm  [SWAP]
  └─rl-opt  253:1    0   10G  0 lvm
```

- Eintragen in `/etc/fstab`
```
/dev/mapper/rl-swap                       none                    swap    defaults                0 0
/dev/mapper/rl-opt                        /opt                    ext4    defaults                1 0
```

- Enable `swap`
```
swapon -av
```

## Verzeichnis `opt` auf die LV `opt` übertragen

- Monit und Docker Service anhalten
```
systemctl stop  monit.service
systemctl stop docker.socket && systemctl status docker.socket 
systemctl stop containerd && systemctl status containerd
systemctl stop docker && systemctl status docker
```

- Verzeichnis `opt` umbenennen, Verzeichnis `opt` erstellen, LV `opt` anbinden
```
mv /opt /opt_old
ls -la /
mkdir /opt
mount -a
df -hT
```


- Daten synchronisieren
```
rsync -aHhP /opt_old/ /opt
ls -la /opt
```

- Docker Service starten
```
systemctl start docker.socket && systemctl status docker.socket 
systemctl start containerd && systemctl status containerd
systemctl start docker && systemctl status docker
```

- Docker container starten
```
manageDC.sh list
manageDC.sh -a start
manageDC.sh list
```

- Monit Service starten
```
systemctl start  monit.service
```

- Prüfen, ob alles läuft
- Verzeichnis `opt_old` löschen
```
rm -rf /opt_old
```


Enjoy !
