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
sudo docker exec -it vault vault operator init 
```

This will output several unseal keys and a root token.
Make sure to save these securely, as they are required to unseal Vault and access it.

To unseal Vault, run the following command three times.
Replace `<unseal_key>` with one of the unseal keys you received during initialization:
```bash
sudo docker exec -it vault vault operator unseal <unseal_key>
```
