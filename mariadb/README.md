# MySQL bakup script

### Install `mysqldump_backup_full.sh` script

```bash
cd /usr/local/bin
if [[ -f mysqldump_backup_full.sh_old ]]; then echo -n "Delete old script"; rm -rf mysqldump_backup_full.sh_old; echo [ Done ]; fi
mv mysqldump_backup_full.sh  mysqldump_backup_full.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/mariadb/mysqldump_backup_full.sh
chmod 0700 mysqldump_backup_full.sh
```

### Install `mysqldump_backup_schema.sh` script

```bash
cd /usr/local/bin
if [[ -f mysqldump_backup_schema.sh_old ]]; then echo -n "Delete old script"; rm -rf mysqldump_backup_schema.sh_old; echo [ Done ]; fi
mv mysqldump_backup_schema.sh  mysqldump_backup_schema.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/mariadb/mysqldump_backup_schema.sh
chmod 0700 mysqldump_backup_schema.sh
```

### Install `mysqldump_docker_backup_full.sh` script

```bash
cd /usr/local/bin
if [[ -f mysqldump_docker_backup_full.sh_old ]]; then echo -n "Delete old script"; rm -rf mysqldump_docker_backup_full.sh_old; echo [ Done ]; fi
mv mysqldump_docker_backup_full.sh  mysqldump_docker_backup_full.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/mariadb/mysqldump_docker_backup_full.sh
chmod 0700 mysqldump_docker_backup_full.sh
```

### Install `mysqldump_docker_backup_schema.sh` script

```bash
cd /usr/local/bin
if [[ -f mysqldump_docker_backup_schema.sh_old ]]; then echo -n "Delete old script"; rm -rf mysqldump_docker_backup_schema.sh_old; echo [ Done ]; fi
mv mysqldump_docker_backup_schema.sh  mysqldump_docker_backup_schema.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/mariadb/mysqldump_docker_backup_schema.sh
chmod 0700 mysqldump_docker_backup_schema.sh


