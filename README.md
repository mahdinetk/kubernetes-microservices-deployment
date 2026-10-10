# Kubernetes Microservices Deployment

Project Overview

This project is a containerized microservices application deployed on Kubernetes. It was developed as a practical DevOps learning project to understand how multiple services communicate, how applications are deployed and managed in a Kubernetes cluster, and how databases are integrated into a microservices architecture.

The application provides basic user management functionality, including user registration, login, device information collection, and displaying a list of registered users.

## Architecture

The application consists of the following components:

Frontend: HTML pages served by Nginx, providing the user interface for login, registration, and viewing users.

Gateway: A FastAPI service that acts as the entry point for API requests and routes them to the appropriate backend microservice.

User Data Service: Handles user-related operations, including registration and login.

User List Service: Retrieves user information from the database and provides it to the frontend through the gateway.

PostgreSQL: Stores user accounts and device information persistently.

Request Flow

User requests follow this general path:

User → Nginx → Gateway → Backend Microservices → PostgreSQL

The backend microservices communicate with PostgreSQL to store or retrieve application data. Kubernetes Services provide internal network connectivity between the application components.

# Installation

## Requirements

Install:

- Docker
- Docker Compose
- kubectl
- Minikube
- Git

Recommended Minikube resources:

- 4 GB RAM
- 2 CPUs
- 10 GB free disk space

## Deploy the project

Clone the repository:

```bash
git clone git@github.com:mahdinetk/kubernetes-microservices-deployment.git
cd kubernetes-microservices-deployment
```

Run the deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

The script automatically:

1. Starts Minikube
2. Creates the Kubernetes namespace
3. Builds the Docker images
4. Loads the images into Minikube
5. Deploys PostgreSQL and persistent storage
6. Creates the required database tables
7. Deploys the microservices and frontend
8. Configures PostgreSQL replication

No manual database setup is required.

The database starts with an empty `users` and `devices` table. Any data created while using the application belongs to the user's own local Kubernetes/PostgreSQL environment.

## Access the application

```bash
minikube service frontend -n microservices
```

## Stop the project

```bash
minikube stop
```

## Remove the project

```bash
kubectl delete namespace microservices
```

To completely remove Minikube:

```bash
minikube delete
```

> **Warning:** deleting the namespace or Minikube cluster can delete the project's Kubernetes resources and persistent data.
