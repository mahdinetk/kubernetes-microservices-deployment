#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

NAMESPACE="microservices"
POD="postgres-0"
REMOTE_USER="pgbackrest"
REMOTE_HOST="10.0.1.25"
PROJECT_DIR="$HOME/kubernetes-microservices-deployment"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

LOCK_ROOT="$HOME/.cache/kubernetes-backup"
mkdir -p "$LOCK_ROOT"
chmod 700 "$LOCK_ROOT"

exec 9>"$LOCK_ROOT/daily.lock"
flock -n 9 || {
    echo "Another configuration backup is running."
    exit 1
}

command -v kubectl >/dev/null
command -v tar >/dev/null
command -v sha256sum >/dev/null

[[ -d "$PROJECT_DIR" ]] || {
    echo "Project directory not found: $PROJECT_DIR"
    exit 1
}

kubectl get namespace "$NAMESPACE" >/dev/null
kubectl exec -n "$NAMESPACE" "$POD" -- true >/dev/null

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
BACKUP_DIR="$TMP_ROOT/$TIMESTAMP"
mkdir -m 700 "$BACKUP_DIR"

echo "Saving Kubernetes resources..."

kubectl get \
    deployments,statefulsets,daemonsets,services,configmaps,\
serviceaccounts,roles,rolebindings,networkpolicies,ingresses,\
persistentvolumeclaims,cronjobs \
    -n "$NAMESPACE" -o yaml \
    > "$BACKUP_DIR/namespaced-resources.yaml"

kubectl get secrets -n "$NAMESPACE" -o yaml \
    > "$BACKUP_DIR/secrets.yaml"
chmod 600 "$BACKUP_DIR/secrets.yaml"

kubectl get \
    namespaces,clusterroles,clusterrolebindings,\
customresourcedefinitions,storageclasses,persistentvolumes \
    -o yaml > "$BACKUP_DIR/cluster-scoped-inventory.yaml"

kubectl get namespace "$NAMESPACE" -o yaml \
    > "$BACKUP_DIR/namespace.yaml"

kubectl version > "$BACKUP_DIR/kubernetes-version.txt" 2>&1 || true
kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt"
kubectl get pods -n "$NAMESPACE" -o wide > "$BACKUP_DIR/pods.txt"

kubectl get deployments,statefulsets,daemonsets,cronjobs \
    -n "$NAMESPACE" \
    -o jsonpath='{range .items[*]}{.kind}{"/"}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}{"  "}{.image}{"\n"}{end}{range .spec.jobTemplate.spec.template.spec.containers[*]}{"  "}{.image}{"\n"}{end}{end}' \
    > "$BACKUP_DIR/image-inventory.txt"

echo "Archiving project files..."

tar -czf "$BACKUP_DIR/project-files.tar.gz" \
    -C "$PROJECT_DIR" \
    --exclude='.git' \
    --exclude='*/.git' \
    --exclude='node_modules' \
    --exclude='*/node_modules' \
    --exclude='__pycache__' \
    --exclude='*/__pycache__' \
    --exclude='*.pyc' \
    --exclude='.venv' \
    --exclude='venv' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='*.pem' \
    --exclude='*.key' \
    --exclude='id_rsa*' \
    --exclude='kubeconfig*' \
    --exclude='*secret*.yaml' \
    --exclude='*secret*.yml' \
    .

(
    cd "$BACKUP_DIR"
    find . -type f ! -name SHA256SUMS -print0 |
        sort -z |
        xargs -0 sha256sum > SHA256SUMS
)

chmod -R go-rwx "$BACKUP_DIR"

echo "Preparing Debian backup directory..."

kubectl exec -n "$NAMESPACE" "$POD" -- \
    ssh -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" \
    'mkdir -p "$HOME/kubernetes-backups/daily" &&
     chmod 700 "$HOME/kubernetes-backups" "$HOME/kubernetes-backups/daily"'

echo "Transferring archive to Debian..."

tar -czf - -C "$TMP_ROOT" "$TIMESTAMP" |
    kubectl exec -i -n "$NAMESPACE" "$POD" -- \
        ssh -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" \
        "cat > \"\$HOME/kubernetes-backups/daily/config-$TIMESTAMP.tar.gz\""

echo "Verifying remote archive and applying daily retention..."

kubectl exec -i -n "$NAMESPACE" "$POD" -- \
    ssh -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" 'bash -s' <<REMOTE
set -Eeuo pipefail
umask 077

cd "\$HOME/kubernetes-backups/daily"
file="config-$TIMESTAMP.tar.gz"

tar -tzf "\$file" >/dev/null
sha256sum "\$file" > "\$file.sha256"
sha256sum -c "\$file.sha256"

find . -maxdepth 1 -type f -name 'config-*.tar.gz' \
    -printf '%T@ %p\n' |
    sort -rn |
    tail -n +8 |
    cut -d' ' -f2- |
    while IFS= read -r old; do
        [[ -n "\$old" ]] && rm -f -- "\$old" "\$old.sha256"
    done

ls -lh "\$file" "\$file.sha256"
REMOTE

echo "Daily configuration backup completed on Debian."
