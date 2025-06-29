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

# Connect another cluster to be managed by ArgoCD

````bash
# Create a Service Account in the target cluster
kubectl apply -f prod-cluster-sa.yaml --context=prod-cluster

# Get the target cluster API Server URL to be used by ArgoCD applications to be deployed into that cluster
kubectl config view --minify --context=prod-cluster -o jsonpath='{.clusters[0].cluster.server}'

# Add the target cluster to ArgoCD
argocd cluster add prod-cluster --server https://<cluster-api-server-url> --name prod-cluster

**Deploy Applications**
```bash
# Apply application manifests
kubectl apply -f applications/
````
