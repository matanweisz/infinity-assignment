# Bastion Host Management Guide

## Installed Tools

- **Docker**: Container runtime
- **AWS CLI**: AWS service management
- **kubectl**: Kubernetes cluster management
- **Helm**: Kubernetes package manager
- **ArgoCD CLI**: GitOps deployment tool
- **Vault CLI**: Secret management
- **k9s**: Kubernetes terminal UI
- **kubectx/kubens**: Context and namespace switching

## Quick Start Commands

### AWS Configuration

```bash
aws configure                    # Configure AWS credentials
aws eks update-kubeconfig --region eu-central-1 --name backend-cluster
aws eks update-kubeconfig --region eu-central-1 --name prod-cluster
```

### Kubernetes Management

```bash
k get nodes                      # List cluster nodes
k get pods --all-namespaces     # List all pods
kubectx                         # Switch between clusters
kubens                          # Switch between namespaces
k9s                             # Launch Kubernetes UI
```

### Docker Operations

```bash
docker ps                       # List running containers
docker images                   # List images
docker logs <container>         # View container logs
```

### ArgoCD Management

```bash
argocd login <argocd-server>    # Login to ArgoCD
argocd app list                 # List applications
argocd app sync <app-name>      # Sync application
```

### Vault Operations

```bash
vault status                    # Check vault status
vault auth -method=userpass     # Authenticate
vault kv get secret/myapp       # Read secret
```
