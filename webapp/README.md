# My Simple Node.js Web Application
This is a minimal Node.js web application that includes:

- A simple home page
- A `/health` endpoint for Kubernetes probes
- Logging of requests
- A Dockerfile for containerization

## Run locally

```bash
npm install
npm start
```

## Run with Docker

```bash
docker build -t webapp .
docker run -p 3000:3000 webapp
```
