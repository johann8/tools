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

<h1 align="center">Umsetzung</h1>

## BIOS Setup

## Hardware RAID erstellen

## Proxmox installieren

# Backup Storage anbinden

# Software RAID erstellen

# LVM Thin Storage für VMs einrichten

# VMs restoren und auf Funktionalität testen 

# Scheduler für Backup einrichten

# SMTP Service konfigurieren

