#!/bin/bash

set -e

echo "==> Starting Minikube..."
minikube start

echo "==> Creating Kubernetes namespace..."
kubectl apply -f k8s/namespace.yaml

echo "==> Building Docker images..."
docker build -t project-frontend:latest ./frontend
docker build -t project-gateway:latest ./backend/gateway
docker build -t project-user-data-service:latest ./backend/user_data_service
docker build -t project-user-list-service:latest ./backend/user_list_service

echo "==> Loading images into Minikube..."
minikube image load project-frontend:latest
minikube image load project-gateway:latest
minikube image load project-user-data-service:latest
minikube image load project-user-list-service:latest

echo "==> Deploying PostgreSQL..."
kubectl apply -f k8s/postgres/postgres-pvc.yaml
kubectl apply -f k8s/postgres/postgres-statefulset.yaml
kubectl apply -f k8s/postgres/postgres-service.yaml

echo "==> Waiting for PostgreSQL..."
kubectl wait \
  --for=condition=ready pod/postgres-0 \
  -n microservices \
  --timeout=120s

echo "==> Creating database tables..."

kubectl exec -i postgres-0 -n microservices -- \
psql -U app -d microservices_db <<'SQL'

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_agent TEXT,
    platform VARCHAR(100),
    screen_width INTEGER,
    screen_height INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SQL

echo "==> Deploying Gateway..."
kubectl apply -f k8s/gateway/gateway-deployment.yaml
kubectl apply -f k8s/gateway/gateway-service.yaml

echo "==> Deploying User Data Service..."
kubectl apply -f k8s/user-data/user-data-deployment.yaml
kubectl apply -f k8s/user-data/user-data-service.yaml

echo "==> Deploying User List Service..."
kubectl apply -f k8s/user-list/user-list-deployment.yaml
kubectl apply -f k8s/user-list/user-list-service.yaml

echo "==> Deploying Frontend..."
kubectl apply -f k8s/frontend/frontend-deployment.yaml
kubectl apply -f k8s/frontend/frontend-service.yaml

echo "==> Configuring PostgreSQL replication..."
kubectl apply -f k8s/replication/postgres-config.yaml
kubectl apply -f k8s/replication/postgres-standby.yaml

echo ""
echo "======================================"
echo "Deployment completed successfully!"
echo "======================================"
echo ""
echo "Open the application with:"
echo ""
echo "    minikube service frontend -n microservices"
echo ""
