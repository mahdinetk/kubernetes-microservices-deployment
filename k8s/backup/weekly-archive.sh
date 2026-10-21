#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

NAMESPACE="microservices"
POD="postgres-0"
REMOTE_USER="pgbackrest"
REMOTE_HOST="10.0.1.25"

kubectl get namespace "$NAMESPACE" >/dev/null
kubectl exec -n "$NAMESPACE" "$POD" -- true >/dev/null

echo "Creating weekly archive on Debian..."

kubectl exec -i -n "$NAMESPACE" "$POD" -- \
    ssh -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" 'bash -s' <<'REMOTE'
set -Eeuo pipefail
umask 077

BACKUP_ROOT="$HOME/kubernetes-backups"
DAILY_ROOT="$BACKUP_ROOT/daily"
WEEKLY_ROOT="$BACKUP_ROOT/weekly"

mkdir -p "$DAILY_ROOT" "$WEEKLY_ROOT"
chmod 700 "$BACKUP_ROOT" "$DAILY_ROOT" "$WEEKLY_ROOT"

exec 9>"$BACKUP_ROOT/.weekly.lock"
flock -n 9 || {
    echo "Weekly archive task already running."
    exit 1
}

LATEST="$(
    find "$DAILY_ROOT" -maxdepth 1 -type f \
        -name 'config-*.tar.gz' -printf '%T@ %p\n' |
        sort -rn |
        head -n 1 |
        cut -d' ' -f2-
)"

if [[ -z "$LATEST" ]]; then
    echo "ERROR: No daily archive found on Debian."
    exit 1
fi

# Verify the daily archive before copying it.
(
    cd "$DAILY_ROOT"
    sha256sum -c "$(basename "$LATEST").sha256"
    tar -tzf "$LATEST" >/dev/null
)

STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$WEEKLY_ROOT/config-$STAMP.tar.gz"

cp -- "$LATEST" "$ARCHIVE.tmp"
mv "$ARCHIVE.tmp" "$ARCHIVE"

(
    cd "$WEEKLY_ROOT"
    sha256sum "$(basename "$ARCHIVE")" \
        > "$(basename "$ARCHIVE").sha256"
    sha256sum -c "$(basename "$ARCHIVE").sha256"
    tar -tzf "$ARCHIVE" >/dev/null
)

# Retain the four newest weekly archives.
find "$WEEKLY_ROOT" -maxdepth 1 -type f \
    -name 'config-*.tar.gz' -printf '%T@ %p\n' |
    sort -rn |
    tail -n +5 |
    cut -d' ' -f2- |
    while IFS= read -r old; do
        [[ -n "$old" ]] && rm -f -- "$old" "$old.sha256"
    done

# Also enforce seven daily archives.
find "$DAILY_ROOT" -maxdepth 1 -type f \
    -name 'config-*.tar.gz' -printf '%T@ %p\n' |
    sort -rn |
    tail -n +8 |
    cut -d' ' -f2- |
    while IFS= read -r old; do
        [[ -n "$old" ]] && rm -f -- "$old" "$old.sha256"
    done

echo "Weekly archive created: $ARCHIVE"
ls -lh "$ARCHIVE" "$ARCHIVE.sha256"
REMOTE

echo "Weekly archive completed on Debian."
