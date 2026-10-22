# Smart Campus Energy Monitoring System

A campus energy monitoring dashboard demonstrating Docker,
Docker Hub, Kubernetes, Jenkins CI/CD, and automatic rollback.

## Features

- Energy consumption dashboard
- Building-wise usage and target comparisons
- Energy alerts and recommendations
- Docker containerization using Nginx
- Kubernetes Deployment with two replicas
- Kubernetes NodePort Service
- Health checks using readiness and liveness probes
- Jenkins pipeline for build, test, push, and deployment
- Fault injection and automatic rollback demonstration

## Sample Data

| Building | Consumption | Target |
|---|---:|---:|
| Academic Block | 125 kWh | 110 kWh |
| Library | 85 kWh | 90 kWh |
| Hostel Block | 145 kWh | 120 kWh |

The values are sample data for demonstration, not live meter readings.

## Project Files

- `index.html` - Dashboard
- `health.html` - Application health endpoint
- `Dockerfile` - Docker image configuration
- `deployment.yaml` - Kubernetes Deployment and Service
- `Jenkinsfile` - CI/CD pipeline and rollback logic
- `.gitignore` - Excludes unnecessary and sensitive files

## Local Docker Test

Build the image:

```powershell
docker build -t smart-campus-energy:local .