#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# FinancePY -- nightly ENCRYPTED backup (replaces backup_to_supabase.sh)
#
# Dumps the local Postgres and encrypts it with a GPG PUBLIC key before it
# touches disk. The private key is NOT on this machine (only the owner has
# it), so a stolen disk / copied backup folder / off-site copy is unreadable.
# Nothing is restored anywhere in plaintext (the old script kept a full
# plaintext replica in Supabase).
#
#   LOCAL_ADMIN_DATABASE_URL=<local postgres, admin role> \
#   BACKUP_GPG_RECIPIENT=<public key fingerprint> bin/backup_encrypted.sh
#
# Restore (on a machine that holds the private key):
#   gpg -d file.dump.gpg > file.dump && pg_restore -d <db> file.dump
# =====================================================================

WEB_CONTAINER="${WEB_CONTAINER:-financespy-web-1}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
RETRIES="${BACKUP_RETRIES:-3}"
RETRY_DELAY_SECONDS="${BACKUP_RETRY_DELAY_SECONDS:-30}"

: "${LOCAL_ADMIN_DATABASE_URL:?LOCAL_ADMIN_DATABASE_URL required (admin role; app role is limited by row level security)}"
: "${BACKUP_GPG_RECIPIENT:?BACKUP_GPG_RECIPIENT required (fingerprint of the backup PUBLIC key)}"

gpg --list-keys "$BACKUP_GPG_RECIPIENT" >/dev/null 2>&1 || { echo "public key $BACKUP_GPG_RECIPIENT not in gpg keyring" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"; chmod 700 "$BACKUP_DIR"
PG_URL="${LOCAL_ADMIN_DATABASE_URL%%\?*}"
STAMP="$(date +%Y%m%d_%H%M%S)"
TMP="$BACKUP_DIR/.financespy_$STAMP.dump.gpg.partial"
FINAL="$BACKUP_DIR/financespy_$STAMP.dump.gpg"

dump_encrypted() {
  docker exec "$WEB_CONTAINER" pg_dump "$PG_URL" -Fc --no-owner --no-privileges --schema=financespy \
    | gpg --batch --yes --trust-model always -r "$BACKUP_GPG_RECIPIENT" --encrypt -o "$TMP"
}

attempt=1
until dump_encrypted; do
  rm -f "$TMP"
  if [ "$attempt" -ge "$RETRIES" ]; then echo "=== FAILED after $attempt attempts ==="; exit 1; fi
  echo "=== attempt $attempt failed, retrying in ${RETRY_DELAY_SECONDS}s ==="
  attempt=$((attempt + 1)); sleep "$RETRY_DELAY_SECONDS"
done

# A dump of a live app is never a few bytes; catch an empty/truncated pipe.
SIZE=$(wc -c < "$TMP")
if [ "$SIZE" -lt 10000 ]; then rm -f "$TMP"; echo "=== FAILED: encrypted dump suspiciously small ($SIZE bytes) ==="; exit 1; fi

mv "$TMP" "$FINAL"; chmod 600 "$FINAL"
find "$BACKUP_DIR" -name 'financespy_*.dump.gpg' -mtime +"$KEEP_DAYS" -delete
echo "=== Encrypted backup completed: $FINAL ($SIZE bytes) at $(date) ==="
