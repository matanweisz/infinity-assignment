## Helm Charts Directory for ArgoCD

This directory contains Helm charts that are synced and managed by ArgoCD. 
It allows for version control and following GitOps principles for managing Kubernetes resources.

**ArgoCD sync happens automatically based on detected changes**

# CD pipeline:
**update-and-commit**: Updates the Helm chart and commits the changes to the repository for ArgoCD to sync and deploy.
