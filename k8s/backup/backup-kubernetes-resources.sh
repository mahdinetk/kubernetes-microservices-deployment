#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

NAMESPACE="microservices"
PROJECT_DIR="$HOME/kubernetes-microservices-deployment"
BACKUP_ROOT="$HOME/kubernetes-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

mkdir -p "$BACKUP_ROOT"
chmod 700 "$BACKUP_ROOT"

# Prevent simultaneous runs from overlapping.
exec 9>"$BACKUP_ROOT/.backup.lock"
flock -n 9 || {
    echo "Another configuration backup is already running."
    exit 1
}

command -v kubectl >/dev/null
command -v tar >/dev/null
command -v sha256sum >/dev/null

[[ -d "$PROJECT_DIR" ]] || {
    echo "Project directory not found: $PROJECT_DIR"
    exit 1
}

# Fail before creating a snapshot if Kubernetes is unavailable.
kubectl get namespace "$NAMESPACE" >/dev/null

mkdir -m 700 "$BACKUP_DIR"

echo "Saving namespace resources..."
kubectl get \
    deployments,statefulsets,daemonsets,services,configmaps,\
serviceaccounts,roles,rolebindings,networkpolicies,ingresses,\
persistentvolumeclaims,cronjobs \
    -n "$NAMESPACE" -o yaml \
    > "$BACKUP_DIR/namespaced-resources.yaml"

echo "Saving Secrets..."
kubectl get secrets -n "$NAMESPACE" -o yaml \
    > "$BACKUP_DIR/secrets.yaml"
chmod 600 "$BACKUP_DIR/secrets.yaml"

echo "Saving cluster-scoped inventory..."
kubectl get \
    namespaces,clusterroles,clusterrolebindings,\
customresourcedefinitions,storageclasses,persistentvolumes \
    -o yaml > "$BACKUP_DIR/cluster-scoped-inventory.yaml"

kubectl get namespace "$NAMESPACE" -o yaml \
    > "$BACKUP_DIR/namespace.yaml"

kubectl version > "$BACKUP_DIR/kubernetes-version.txt" 2>&1 || true
kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt"
kubectl get pods -n "$NAMESPACE" -o wide > "$BACKUP_DIR/pods.txt"

echo "Saving image inventory..."
kubectl get deployments,statefulsets,daemonsets,cronjobs \
    -n "$NAMESPACE" \
    -o jsonpath='{range .items[*]}{.kind}{"/"}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}{"  "}{.image}{"\n"}{end}{range .spec.jobTemplate.spec.template.spec.containers[*]}{"  "}{.image}{"\n"}{end}{end}' \
    > "$BACKUP_DIR/image-inventory.txt"

echo "Archiving project files..."
tar -czf "$BACKUP_DIR/project-files.tar.gz" \
    -C "$PROJECT_DIR" \
    --exclude='./.git' \
    .

# Generate checksums after all backup files have been written.
(
    cd "$BACKUP_DIR"
    find . -type f ! -name SHA256SUMS -print0 \
        | sort -z \
        | xargs -0 sha256sum > SHA256SUMS
)

chmod -R go-rwx "$BACKUP_DIR"

echo
echo "Backup completed successfully."
echo "Location: $BACKUP_DIR"
du -sh "$BACKUP_DIR"
