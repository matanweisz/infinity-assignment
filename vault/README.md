# Vault Instance - Docker Compose Setup

This directory contains the docker compose file required to run a Vault instance on an EC2 instance.

## Overview

The provided `docker-compose.yml` file sets up a self-hosted Vault secret manager server.
This instance is used to manage secrets and sensitive data securely.

## Requirements

- An AWS EC2 instance.
- Docker and Docker Compose installed on the instance.

- Change the private IP address in the `docker-compose.yml` file to the private IP address of the EC2 instance.

- Copy the vault-config.hcl file to the instance.
- Create a directory for Vault data and logs with:
  ```bash
  mkdir -p ./vault/data
  mkdir -p ./vault/logs

  sudo chown -R 100:100 ./vault/data ./vault/logs
  ```

## Usage

Start Vault with:

```bash
sudo docker compose up -d
```

Check the container logs to see if Vault is ready:

```bash
sudo docker compose logs -f vault
```

To initialize Vault, run the following command:

```bash
sudo docker exec -it vault-server vault operator init
```

This will output several unseal keys and a root token.
Make sure to save these securely, as they are required to unseal Vault and access it.

To unseal Vault, run the following command three times.
Replace `<unseal_key>` with one of the unseal keys you received during initialization:

```bash
sudo docker exec -it vault-server vault operator unseal <unseal_key>
```
