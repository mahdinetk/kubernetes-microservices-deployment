# Kubernetes Microservices Deployment

## Project Overview
This project is a containerized microservices application deployed on Kubernetes. It was developed as a practical DevOps learning project to understand how multiple services communicate, how applications are deployed and managed in a Kubernetes cluster, and how databases are integrated into a microservices architecture.

The application provides basic user management functionality, including user registration, login, device information collection, and displaying a list of registered users.
## Architecture

- **Frontend:** Nginx
- **API Gateway:** FastAPI
- **Microservices:** User Data and User List
- **Database:** PostgreSQL primary and standby
- **Ingress:** Traefik

**Request Flow**

External requests follow this general path:

User → Traefik → Frontend / Gateway → Backend Microservices → PostgreSQL

## Requirements

- Docker
- Minikube
- kubectl
- Helm
- OpenSSL

## Deployment

Clone the repository and run:

```bash
git clone https://github.com/mahdinetk/kubernetes-microservices-deployment.git
cd kubernetes-microservices-deployment

chmod +x deploy.sh
./deploy.sh
```

The script starts Minikube, builds and loads Docker images, deploys the application and PostgreSQL, installs Traefik, and applies the routing configuration.

## Access the Application

Add this entry to `/etc/hosts`:

```text
127.0.0.1 app.local
```

Start port forwarding:

```bash
sudo env KUBECONFIG=$HOME/.kube/config \
kubectl port-forward --address 127.0.0.1 \
-n traefik svc/traefik 80:80 443:443
```

Open:

- Application: https://app.local
- API documentation: https://app.local/docs

The TLS certificate is self-signed, so browsers may show a security warning.

## Remove the Deployment

```bash
kubectl delete namespace microservices
helm uninstall traefik -n traefik
minikube stop
```

## Monitoring

The project uses Prometheus and Grafana to monitor Kubernetes infrastructure and application availability. Blackbox Exporter is used to check HTTP endpoint availability.

Monitoring configurations are stored in the repository, including:

- **Grafana dashboards:** JSON files for visualizing monitoring metrics.
- **Alert rules:** YAML files defining conditions that require attention.

These configurations make the monitoring setup easier to maintain, reproduce, and extend.


## Backup and Disaster Recovery

The project uses Bash scripts for Kubernetes configuration backups and pgBackRest for PostgreSQL backups in ```k8s/backup``` directory.

### Configuration

- **Backup server:** Update the server IP and connection settings in the backup scripts and pgBackRest configuration to match your environment.
- **Kubernetes resources:** Backup CronJobs, PVCs, and related resources must be created manually using the provided configuration files or commands.
- **Backup storage:** Configuration archives and PostgreSQL backups are stored on the configured backup server.

### Backup Schedule

| Backup | Schedule |
|---|---|
| Kubernetes configuration | Daily |
| Configuration archive | Weekly |
| PostgreSQL full backup | Sunday, 02:00 UTC |
| PostgreSQL incremental backup | Monday–Saturday, 02:00 UTC |

Schedules apply only after the relevant CronJobs are created and configured.

### Recovery

1. Restore Kubernetes configuration and project files.
2. Recreate required Kubernetes resources, including PVCs and CronJobs.
3. Restore PostgreSQL data separately using pgBackRest.

**Note:** Update environment-specific settings before deployment. Configuration archives do not replace PostgreSQL database backups.
