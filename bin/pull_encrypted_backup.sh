#!/usr/bin/env bash
# Off-site copy: pulls the newest encrypted backup from the server into a local
# folder (e.g. a synced Drive folder). Files are GPG-encrypted, safe to sync.
#   BACKUP_SSH=fabrizio@100.105.31.71 DEST=~/Drive/backups bin/pull_encrypted_backup.sh
set -euo pipefail
: "${BACKUP_SSH:?user@host required}"
: "${DEST:?destination folder required}"
mkdir -p "$DEST"
LATEST=$(ssh -o BatchMode=yes "$BACKUP_SSH" 'ls -1t ~/backups/financespy_*.dump.gpg 2>/dev/null | head -1')
[ -n "$LATEST" ] || { echo "no encrypted backup found on server" >&2; exit 1; }
scp -q "$BACKUP_SSH:$LATEST" "$DEST/"
echo "pulled $(basename "$LATEST") -> $DEST"
