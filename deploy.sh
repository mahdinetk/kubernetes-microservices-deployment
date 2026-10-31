
#!/bin/bash

set -e

echo "==> Starting Minikube..."
minikube start

echo "==> Creating Kubernetes namespace..."
kubectl apply -f k8s/namespace.yaml

echo "==> Installing Traefik..."
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo update

helm upgrade --install traefik traefik/traefik \
  --version 42.1.3 \
  --namespace traefik \
  --create-namespace \
  --values k8s/traefik/values.yaml

kubectl rollout status deployment/traefik -n traefik --timeout=180s

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
kubectl apply -f k8s/postgres/replication/postgres-config.yaml
kubectl apply -f k8s/postgres/replication/postgres-standby.yaml

echo "==> Configuring Traefik TLS..."
mkdir -p k8s/traefik/certs

if [ ! -f k8s/traefik/certs/app.local.crt ] || \
   [ ! -f k8s/traefik/certs/app.local.key ]; then
    openssl req -x509 -nodes -days 365 \
      -newkey rsa:2048 \
      -keyout k8s/traefik/certs/app.local.key \
      -out k8s/traefik/certs/app.local.crt \
      -subj "/CN=app.local" \
      -addext "subjectAltName=DNS:app.local"
fi

kubectl create secret tls app-local-tls \
  --cert=k8s/traefik/certs/app.local.crt \
  --key=k8s/traefik/certs/app.local.key \
  -n microservices \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying Traefik routing configuration..."
kubectl apply -f k8s/traefik/middleware.yaml
kubectl apply -f k8s/traefik/ingressroute.yaml
kubectl apply -f k8s/traefik/api-ingressroute.yaml

echo ""
echo "======================================"
echo "Deployment completed successfully!"
echo "======================================"
echo ""
echo "Add this entry to /etc/hosts:"
echo "127.0.0.1 app.local"
echo ""
echo "Run this command to access the application:"
echo "sudo env KUBECONFIG=\$HOME/.kube/config kubectl port-forward --address 127.0.0.1 -n traefik svc/traefik 80:80 443:443"
echo ""
echo "Then open: https://app.local"

