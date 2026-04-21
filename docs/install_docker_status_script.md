### Install `docker_status.sh` script

> [!NOTE]
> The script `docker_status.sh` run with the "exited" option displays the stopped Docker containers and attempts to restart them.
> The script `docker_status.sh` run with the "healthy" option displays the status of Docker containers.

- Download script

```bash
wget https://raw.githubusercontent.com/johann8/tools/refs/heads/master/docker_status.sh -O /usr/local/bin/docker_status.sh
```

- Set script permissions

```bash
chmod 0700 /usr/local/bin/docker_status.sh
```

- Show script help

```bash
docker_status.sh -h | help
```

- Show script version

```bash
docker_status.sh -v | version
```

- Show status `exited` docker container and rerun them
                  
```bash
docker_status.sh exited
```

- Show status `healthy` docker container

```bash
docker_status.sh healty
```
