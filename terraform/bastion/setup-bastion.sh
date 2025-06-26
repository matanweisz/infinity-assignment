#!/bin/bash
# Manual Bastion Host Setup Script
# Run this script on your bastion host to install all the required tools

set -e # Exit on any error

echo "Starting bastion host setup..."

# Update system packages
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install basic dependencies
echo "Installing basic dependencies..."
sudo apt-get install -y \
    curl \
    wget \
    unzip \
    jq \
    git \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
echo "Installing Docker..."
# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

echo "Docker installed successfully"

# Install AWS CLI v2
echo "☁️  Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify AWS CLI installation
aws --version
echo "AWS CLI installed successfully"

# Install kubectl
echo "Installing kubectl..."
# Download latest stable version
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify kubectl installation
kubectl version --client
echo "kubectl installed successfully"

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm installation
helm version
echo "Helm installed successfully"

# Install ArgoCD CLI
echo "Installing ArgoCD CLI..."
# Get latest ArgoCD version
ARGOCD_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r .tag_name)
curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"

# Install ArgoCD CLI
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Verify ArgoCD CLI installation
argocd version --client
echo "ArgoCD CLI installed successfully"

# Install Vault CLI
echo "Installing Vault CLI..."
# Get latest Vault version
VAULT_VERSION=$(curl -s https://api.github.com/repos/hashicorp/vault/releases/latest | jq -r .tag_name | sed 's/v//')
curl -sSL -o vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"

# Install Vault CLI
unzip vault.zip
sudo install -m 755 vault /usr/local/bin/vault
rm vault vault.zip

# Verify Vault CLI installation
vault version
echo "Vault CLI installed successfully"

# Clean up
echo "Cleaning up temporary files..."
rm -rf /tmp/aws /tmp/awscliv2.zip kubectl

exec bash

echo "Bastion host setup completed successfully!"
echo ""
echo "Next steps:"
echo "Configure AWS CLI: aws configure"
echo "Configure kubectl for your clusters:"
echo "   aws eks update-kubeconfig --region eu-central-1 --name backend-cluster"
echo "   aws eks update-kubeconfig --region eu-central-1 --name prod-cluster"
