# GitLab Instance - Docker Compose Setup

This directory contains the docker compose file required to run a GitLab instance on an EC2 instance.

## Overview

The provided `docker-compose.yml` file sets up a self-hosted GitLab server.
This instance is used as a source control platform and a CI/CD server for my web application.
It includes the necessary configurations for GitLab, such as ports, volumes, and environment variables.

## Requirements
 
- An AWS EC2 instance large enough to run GitLab (Recommended: t3.medium or larger).
- Docker and Docker Compose installed on the instance.
- Sufficient disk space for GitLab data (at least 20GB recommended).

## Usage   
**Start GitLab:**
```bash
docker compose up -d
```
