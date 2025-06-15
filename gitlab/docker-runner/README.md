# GitLab Runner (Docker) Setup

This directory contains the configuration files used to run a GitLab Runner as a Docker container.
This setup was used for local testing and CI/CD pipeline execution before deploying the runner to the EKS cluster using helm.

## Usage

- Use the provided Docker Compose or Docker configuration to start a GitLab Runner container.
- Register the runner with your GitLab instance using the registration token.
- The runner will be available to execute CI/CD jobs for your projects.

## Notes

- This setup is intended for development and testing purposes, the GitLab Runner should be deployed inside the EKS cluster.
