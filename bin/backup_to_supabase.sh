#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# FinancePY — Nightly backup: local Postgres -> Supabase
#
# Postgres became primary on this PC on 2026-09-01 (see compose.local.yml)
# specifically to cut the ~250ms/query round-trip to Supabase in Oregon.
# Supabase is kept around as a live, ready-to-fail-over-to replica: this
# script dumps the local DB and restores it into Supabase every night, so
# if this PC dies the app can point back at Supabase (same DATABASE_URL
# shape as before the migration) in minutes with no data loss.
#
# Runs via host crontab, not inside a container -- it shells out to
# `docker exec` on the running web container, which already has
# pg_dump/pg_restore (they ship with the Postgres client libs the `pg`
# gem needs).
#
# Usage (env vars normally come from .env.local via the crontab entry):
#   DATABASE_URL=<local postgres> SUPABASE_BACKUP_URL=<supabase> bin/backup_to_supabase.sh
# =====================================================================

WEB_CONTAINER="${WEB_CONTAINER:-financespy-web-1}"
DUMP_PATH="/tmp/financespy_backup_$(date +%Y%m%d_%H%M%S).dump"

: "${DATABASE_URL:?DATABASE_URL requerido (Postgres local, fuente del backup)}"
: "${SUPABASE_BACKUP_URL:?SUPABASE_BACKUP_URL requerido (destino del backup)}"

echo "=== 1. Dumping local Postgres ==="
docker exec "$WEB_CONTAINER" pg_dump "$DATABASE_URL" \
  -Fc --no-owner --no-privileges \
  --schema=financespy --schema=extensions --schema=public \
  -f "$DUMP_PATH"

echo "=== 2. Restoring into Supabase (clean, replaces the prior backup) ==="
docker exec "$WEB_CONTAINER" pg_restore \
  --no-owner --no-privileges --clean --if-exists \
  -d "$SUPABASE_BACKUP_URL" \
  "$DUMP_PATH"

echo "=== 3. Cleaning up dump file ==="
docker exec "$WEB_CONTAINER" rm -f "$DUMP_PATH"

echo "=== Backup to Supabase completed: $(date) ==="
