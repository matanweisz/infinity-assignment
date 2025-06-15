# ArgoCD Configuration Directory

This directory contains all the configuration files i used to setup and manage ArgoCD in my EKS cluster.

## Setup Instructions



# Add ArgoCD Helm repository
```bash
# Add the ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

# Install ArgoCD with Helm
```bash
# Create the namespace for ArgoCD
kubectl create namespace argocd

# Install ArgoCD using Helm with custom values
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=ClusterIP \
  --set server.ingress.enabled=false \
  --set server.extraArgs[0]="--insecure" \
  --set configs.params."server\.insecure"=true
```

# Apply ArgoCD Ingress configuration`
```bash
kubectl apply -f argocd-ingress.yaml

# Verify Ingress Creation
kubectl get ingress -n argocd
```

# Access ArgoCD
```bash 
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Deploy Applications**
```bash
# Apply application manifests
kubectl apply -f applications/
```

## ArgoCD Settings
Key configurations in my setup:

- **Auto-sync**: Enabled to automatically apply changes from the helm-charts Git repository
- **Self-heal**: Enabled to correct manual cluster changes
- **Prune**: Enabled to remove resources that are no longer defined in the Git repository
- **Health checks**: Enabled to ensure the applications are healthy and running as expected
