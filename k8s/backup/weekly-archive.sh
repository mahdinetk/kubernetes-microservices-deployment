
#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

BACKUP_ROOT="$HOME/kubernetes-backups"
WEEKLY_ROOT="$BACKUP_ROOT/weekly"
LOG="$BACKUP_ROOT/weekly-archive.log"

mkdir -p "$BACKUP_ROOT" "$WEEKLY_ROOT"
chmod 700 "$BACKUP_ROOT" "$WEEKLY_ROOT"

exec 9>"$BACKUP_ROOT/.weekly.lock"
flock -n 9 || {
    echo "Weekly archive task already running."
    exit 1
}

# Select the newest completed daily snapshot.
LATEST=""
while IFS= read -r candidate; do
    if [[ -f "$candidate/SHA256SUMS" ]] &&
       (cd "$candidate" && sha256sum -c SHA256SUMS >/dev/null 2>&1); then
        LATEST="$candidate"
        break
    fi
done < <(
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
        ! -name weekly \
        ! -name 'recovery-test-*' \
        -printf '%T@ %p\n' |
    sort -rn | cut -d' ' -f2-
)

if [[ -z "$LATEST" ]]; then
    echo "ERROR: No valid daily backup found." | tee -a "$LOG"
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
TEMP="$WEEKLY_ROOT/.weekly-$STAMP.tmp"
ARCHIVE="$WEEKLY_ROOT/config-$STAMP.tar.gz"

mkdir "$TEMP"
trap 'rm -rf "$TEMP"' EXIT

# Store a self-contained copy of the selected configuration snapshot.
cp -a "$LATEST" "$TEMP/snapshot"

tar -czf "$ARCHIVE.tmp" -C "$TEMP" snapshot
mv "$ARCHIVE.tmp" "$ARCHIVE"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

# Verify the archive before removing any old backups.
tar -tzf "$ARCHIVE" >/dev/null
sha256sum -c "$ARCHIVE.sha256"

rm -rf "$TEMP"
trap - EXIT

# Retain the four newest weekly archives and their checksum files.
find "$WEEKLY_ROOT" -maxdepth 1 -type f \
    -name 'config-*.tar.gz' -printf '%T@ %p\n' |
    sort -rn | tail -n +5 | cut -d' ' -f2- |
    while IFS= read -r old; do
        [[ -n "$old" ]] || continue
        rm -f -- "$old" "$old.sha256"
    done

# Retain the seven newest daily snapshot directories.
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
    ! -name weekly \
    ! -name 'recovery-test-*' \
    -printf '%T@ %p\n' |
    sort -rn | tail -n +8 | cut -d' ' -f2- |
    while IFS= read -r old; do
        [[ -n "$old" ]] || continue
        case "$old" in
            "$BACKUP_ROOT"/*)
                rm -rf -- "$old"
                ;;
        esac
    done

echo "Weekly archive created: $ARCHIVE" | tee -a "$LOG"
echo "Source snapshot: $LATEST" | tee -a "$LOG"
echo "Retention completed." | tee -a "$LOG"

