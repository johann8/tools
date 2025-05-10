<h1 align="center">Bash script - Dump and restore postgreSQL</h1>

#### Install script `postgresql_dump_docker.sh`

```bash
cd /usr/local/bin
if [[ -f postgresql_dump_docker.sh_old ]]; then
   echo -n "Delete old script"
   rm -rf postgresql_dump_docker.sh_old
   echo "[ Done ]"
fi
mv postgresql_dump_docker.sh postgresql_dump_docker.sh_old
wget https://raw.githubusercontent.com/johann8/tools/master/postgresql/postgresql_dump_docker.sh
chmod 0700 postgresql_dump_docker.sh
```

#### Install `crontab`

```bash
crontab -e
----
# Dump PostgreSQL DB
25  4  *  *  *  /usr/local/bin/postgresql_dump_docker.sh > /dev/null 2>&1
----
```

#### Recovery database

- Path to backup files: `/mnt/nfsStorage/mc/databases/postgreSQL`

- Name of the database: authentikdb

- Name of the `docker container service`: postgresql

- `Docker container name`: authentik-postgres 


```bash
# show backup files
ls -l /mnt/nfsStorage/mc/databases/postgreSQL/
----
insgesamt 4556
-rw-r--r-- 1 root root 1581315  7. Mai 20:37 pg_dump_authentikdb_2025-05-07_20h-37m.tar.gz
-rw-r--r-- 1 root root 1567741  8. Mai 04:20 pg_dump_authentikdb_2025-05-08_04h-20m.tar.gz
-rw-r--r-- 1 root root 1510207  9. Mai 09:04 pg_dump_authentikdb_2025-05-09_09h-04m.tar.gz
----

# create tmp dir
mkdir /tmp/recovery

# Set some vars
POSTGRES_DB=authentikdb
POSTGRES_USER=postgres
POSTGRES_CONTAINER_NAME=authentik-postgres
POSTGRES_CONTAINER_SERVICE_NAME=postgresql


# unzip backup into recovery directory
tar -xvzf /mnt/nfsStorage/mc/databases/postgreSQL/pg_dump_${POSTGRES_DB}_2025-05-09_09h-04m.tar.gz -C /tmp/recovery --atime-preserve --preserve-permissions

# Stop monit service
systemctl stop monit

# Go to docker container directory
cd /opt/authentik/

# Stop docker stack
docker compose down

# Run only postgres container
docker compose up -d ${POSTGRES_CONTAINER_SERVICE_NAME}

# Create dump of database to be deleted "authentikdb"
#docker compose exec postgresql pg_dump -U postgres -d authentikdb -cC > pg_dump_authentikdb.sql
docker exec -it ${POSTGRES_CONTAINER_NAME} pg_dump -U ${POSTGRES_USER} -d ${POSTGRES_DB} -cC >  pg_dump_${POSTGRES_DB}_`date "+%Y-%m-%d_%Hh-%Mm"`.sql 

# Delete database "authentikdb"
docker exec -it ${POSTGRES_CONTAINER_NAME} psql -U ${POSTGRES_USER} -d postgres -c "DROP DATABASE authentikdb;"

# Recreate docker container
docker compose up --force-recreate -d ${POSTGRES_CONTAINER_SERVICE_NAME}

# recovery database "authentikdb"
cat /tmp/recovery/pg_dump_${POSTGRES_DB}_2025-05-09_09h-04m.sql | docker compose exec -T ${POSTGRES_CONTAINER_SERVICE_NAME} psql -U postgres

# restart docker container
docker compose up --force-recreate -d ${POSTGRES_CONTAINER_SERVICE_NAME}
docker compose logs -f

# If no errors are seen, then restart docker stack
docker compose down && docker compose up -d
docker compose logs -f

# Start monit service
systemctl start monit
systemctl status monit
```
#### Install `logrotate` file

```bash
cat > /etc/logrotate.d/postgresqldump << 'EOL'
/var/log/postgresql_dump_docker.log {
    weekly
    missingok
    rotate 4
    compress
}
EOL
```

Enjoy!

