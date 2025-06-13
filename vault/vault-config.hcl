# Enables Vault's web UI
ui = true

# Vault listener for API/UI traffic
listener "tcp" {
  address     = "0.0.0.0:8200"  
  tls_disable = true            # Disable TLS because ALB handles SSL termination
}

# Storage backend configuration, stores Vault state locally
storage "file" {
  path = "/vault/data"
}

# External address used by Vault in UI and CLI redirects
api_addr = "https://vault.matanweisz.xyz"
