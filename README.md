# Home Assignment Project Setup

This directory contains all configuration files and resources used to provision and configure this project I created for InfinityLabs R&D.

## Project Overview

The goal of this project is to run a Node.js web application with the following components:

- **GitLab Instance**: For source control and CI/CD pipelines.
- **Vault Instance**: For secret management, used in the application docker image build process.
- **ArgoCD**: For GitOps-based continuous deployment of the web application.
- **Node.js Web App**: A simple web application.
- **GitLab Runner**: To execute CI/CD pipelines within the EKS cluster.
- **EKS Cluster**: Provides a scalable, secure, and managed Kubernetes environment for running the application and runner with high availability.

## Directory Contents

- **Docker Compose**: YAML files that run GitLab and Vault as Docker containers on EC2 instances.
- **Terraform**: Used for the provisioning of the entire project infrastructure in AWS.
- **Configuration Files**: Used for specific configurations.

---
