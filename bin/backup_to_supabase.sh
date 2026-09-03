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
#   LOCAL_ADMIN_DATABASE_URL=<local postgres, superuser> SUPABASE_BACKUP_URL=<supabase> bin/backup_to_supabase.sh
# =====================================================================

WEB_CONTAINER="${WEB_CONTAINER:-financespy-web-1}"
DUMP_PATH="/tmp/financespy_backup_$(date +%Y%m%d_%H%M%S).dump"

: "${LOCAL_ADMIN_DATABASE_URL:?LOCAL_ADMIN_DATABASE_URL requerido (Postgres local, rol admin -- accounts/entries tienen FORCE ROW LEVEL SECURITY, el rol restringido de la app no puede leer todas las familias sin esto)}"
: "${SUPABASE_BACKUP_URL:?SUPABASE_BACKUP_URL requerido (destino del backup)}"

# pg_dump/pg_restore use plain libpq URI parsing, which doesn't understand
# Rails' schema_search_path query param (ActiveRecord-specific) -- strip it.
LOCAL_PG_URL="${LOCAL_ADMIN_DATABASE_URL%%\?*}"
SUPABASE_PG_URL="${SUPABASE_BACKUP_URL%%\?*}"

# Only the financespy schema -- this Supabase project's `public` schema
# belongs to the CD&Co ERP app (shares the same project/database), NOT
# FinancePY. Restoring into `public` here would clobber real ERP data.
echo "=== 1. Dumping local Postgres (schema: financespy only) ==="
docker exec "$WEB_CONTAINER" pg_dump "$LOCAL_PG_URL" \
  -Fc --no-owner --no-privileges \
  --schema=financespy \
  -f "$DUMP_PATH"

echo "=== 2. Restoring into Supabase (schema: financespy only, clean, replaces the prior backup) ==="
docker exec "$WEB_CONTAINER" pg_restore \
  --no-owner --no-privileges --clean --if-exists \
  -d "$SUPABASE_PG_URL" \
  "$DUMP_PATH"

echo "=== 3. Cleaning up dump file ==="
docker exec "$WEB_CONTAINER" rm -f "$DUMP_PATH"

echo "=== Backup to Supabase completed: $(date) ==="
