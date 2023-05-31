<h1 align="center">ProxMox - Umzug auf die neue Hardware</h1>

- [Serverbestellung](#serverbestellung)
- [Vorbereitung](#vorbereitung)
- [Umsetzung](#umsetzung)
  - [BIOS Setup](#bios-setup)
  - [Hardware RAID erstellen](#hardware-raid-erstellen)
  - [Proxmox installieren](#proxmox-installieren)
  - [Backup Storage anbinden](#backup-storage-anbinden)
  - [Software RAID erstellen](#software-raid-erstellen)
  - [LVM Thin Storage für VMs einrichten](#lvm-thin-storage-für-vms-einrichten)
  - [VMs restoren und auf Funktionalität testen](#vms-restoren-und-auf-funktionalität-testen)
  - [Scheduler für Backup einrichten](#scheduler-für-backup-einrichten)
  - [SMTP Service konfigurieren](#smtp-service-konfigurieren)

## Serverbestellung
Der Server wird bei [Coreto](https://www.rect.coreto.de/de/tower-server-systeme/mid-range-tower-server.html) besstellt. Der Server hat ein Mid-Range Tower Gehäuse - Silent Edition mit Intel Xeon CPU. Für das Betriebssystem wird ein Hardware RAID-Controller mit drei Festplatten `HDD (SAS) 4TB` benutzt. Es wird ein RAID1 mit einer Hot Spare HDD erstellt. Für VM Storage wird ein Software RAID1 mit zwei NVMe PCIe SSD-Karten `1,6 TB NVMe SSD Samsung PM1735 Series (1.000.000 IOPS, 7000 MB/s lesen, 8760 TBW, PCIe Gen4 x8)` erstellt.

## Vorbereitung
- Die Konfiguration des alten Servers sichern und über MeshCentral Server auf den USB-Stick laden

```bash
hostname -f > /root/hostname.txt
crontab -l > /root/crontab.txt
df -hT > /root/df-hT.txt
tar -czvf /tmp/etc.tgz /etc
tar -czvf /tmp/root.tgz /root
```

- Die IP-Adresse und den Hostnamen (FQDN) für den neuen Server vergeben z.B.

```
IP: 192.168.25.225
Hostname: pve02.int.myfirma.de
IPMI IP: 192.168.25.253
```
- Über Webinterface von Proxmox folgende Screenshots anfertigen und über MeshCentral Server auf den USB-Stick laden

```
1. Datacenter -> Storage
2. Datacenter -> Backup 
```
- Die Images von allen VMs erstellen: Mode=Stop 

- Ein USB-Stick mit [Proxmox ISO](https://www.proxmox.com/de/downloads/category/iso-images-pve) mit Hilfe von [Ventoy Software](https://www.ventoy.net/en/download.html) erstellen

<h1 align="center">Umsetzung</h1>

## BIOS Setup

## Hardware RAID erstellen

## Proxmox installieren

## Backup Storage anbinden

## Software RAID erstellen

```bash
# install mdadm
apt-get install mdadm

# list block devices
lsblk

# create RAID1
mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/nvme0n1 /dev/nvme1n1

# checking status
cat /proc/mdstat
# or
mdadm -D /dev/md0

### Saving the Array Layout
cat /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | tee -a /etc/mdadm/mdadm.conf
cat /etc/mdadm/mdadm.conf

# Wait until resync is finished

# enable mdmonitor service
systemctl enable mdmonitor --now
systemctl status mdmonitor
systemctl list-units -t service
ls -la /var/run/mdadm/

# mdadm Debian configuration
vim /etc/default/mdadm

# reboot server
reboot 

# after reboot check RAID
cat /proc/mdstat
# or
mdadm -D /dev/md0
lsblk
```

## LVM Thin Storage für VMs einrichten

```bash
# list block devices
lsblk

# create Phyisical Volume (PV) vorbereiten, wobei -ff = force und -y = means answering everything with yes, metadatasize is LVM2 default with 512Byte
pvcreate -y -ff /dev/md0

# When this message appears: Cannot use /dev/md0: device is partitioned, then
wipefs -a /dev/md0

# show status
pvs
pvdisplay

# create Volume Group (VG) with name "vmstorage"
vgcreate vmstorage /dev/md0

# show status
pvdisplay
vgdisplay

# create logische Volumen (LV) with 90% size of VG "vmstorage" with name LV "vmdata"  (-l=size, -T=thin, -n=name)
# lvcreate -l100%FREE -T -n vmdata vmstorage
lvcreate -l90%FREE -T -n vmdata vmstorage

# When using LVM thin provisioning you're looking for the left-most attribute bit to be V, t or T. Here's an example:
lvs
----------------------------------------------------------------------------------------------
  LV     VG        Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  data   pve       twi-a-tz--  3.50t             0.00   0.19
  root   pve       -wi-ao---- 80.00g
  swap   pve       -wi-ao----  8.00g
  vmdata vmstorage twi-a-tz-- <1.31t             0.00   10.44
----------------------------------------------------------------------------------------------
```
- Über Webinterface von Proxmox LVM-Thin Storage anlegen\
Rechenzentrum -> Storage -> Button "Hinzufügen" -> "LVM thin" klicken
Die Felder wie auf dem Bild konfigurieren
![LVM-Thin Storage](https://raw.githubusercontent.com/johann8/tools/master/proxmox/assets/screenshots/storage_lvm.png)

## VMs restoren und auf Funktionalität testen 

## Scheduler für Backup einrichten

## SMTP Service konfigurieren

- Um die Statusemails versenden zu können, muss der SMTP Service eingerichtet werden
```bash
# check if postfix is installed
netstat -tulpen |grep 25
-----------------------------
tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      0          30853      1284/master
tcp6       0      0 ::1:25                  :::*                    LISTEN      0          30854      1284/master
-----------------------------

# install postfix
apt-get install postfix libsasl2-modules

# backup main.cf
cp /etc/postfix/main.cf /etc/postfix/main.cf_backup

# Change /etc/postfix/main.cf to include/change these lines:
vim /etc/postfix/main.cf
----------------------------
#
### JH add on 30.05.23
#
relayhost = [smtp.myfirma.de]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_generic_maps = hash:/etc/postfix/generic
compatibility_level = 2
----------------------------


# Create an /etc/postfix/sasl_passwd file with:
vim /etc/postfix/sasl_passwd
-------------------------
[smtp.myfirma.de]:587    helpdesk@myfirma.de:MySuperPassword
-------------------------
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd


# map root als pve02
vim /etc/postfix/generic
------------------------------
root@pve02.int.myfirma.de          pve02@int.myfirma.de
-------------------------------
postmap /etc/postfix/generic
chmod 600 /etc/postfix/generic

# restart postfix service
systemctl restart postfix
systemctl status postfix

# teste mdadm sent mail report
mdadm --monitor --scan --test --oneshot /dev/md0

# create cronjob
crontab -e
---------------------------
# run mdadm monitoring
#min hour day mon dow command
0  22 * * 7 /usr/sbin/mdadm --monitor --test --oneshot /dev/md0
---------------------------
```

Enjoy!
