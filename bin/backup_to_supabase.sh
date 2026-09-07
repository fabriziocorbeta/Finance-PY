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
RETRIES="${BACKUP_RETRIES:-3}"
RETRY_DELAY_SECONDS="${BACKUP_RETRY_DELAY_SECONDS:-30}"

: "${LOCAL_ADMIN_DATABASE_URL:?LOCAL_ADMIN_DATABASE_URL requerido (Postgres local, rol admin -- accounts/entries tienen FORCE ROW LEVEL SECURITY, el rol restringido de la app no puede leer todas las familias sin esto)}"
: "${SUPABASE_BACKUP_URL:?SUPABASE_BACKUP_URL requerido (destino del backup)}"

# 2026-09-07: a real 3am run died silently mid-restore with no error in the
# log (likely a transient network blip -- the notebook's SSH/Tailscale/
# cloudflared tunnel had been flaky earlier that same night). Retry each
# network-facing step a few times with a delay instead of failing the whole
# night's backup on one blip.
retry() {
  local attempt=1
  until "$@"; do
    if [ "$attempt" -ge "$RETRIES" ]; then
      echo "=== FAILED after $attempt attempts: $* ==="
      return 1
    fi
    echo "=== Attempt $attempt failed, retrying in ${RETRY_DELAY_SECONDS}s: $* ==="
    attempt=$((attempt + 1))
    sleep "$RETRY_DELAY_SECONDS"
  done
}

# pg_dump/pg_restore use plain libpq URI parsing, which doesn't understand
# Rails' schema_search_path query param (ActiveRecord-specific) -- strip it.
LOCAL_PG_URL="${LOCAL_ADMIN_DATABASE_URL%%\?*}"
SUPABASE_PG_URL="${SUPABASE_BACKUP_URL%%\?*}"

# Only the financespy schema -- this Supabase project's `public` schema
# belongs to the CD&Co ERP app (shares the same project/database), NOT
# FinancePY. Restoring into `public` here would clobber real ERP data.
echo "=== 1. Dumping local Postgres (schema: financespy only) ==="
retry docker exec "$WEB_CONTAINER" pg_dump "$LOCAL_PG_URL" \
  -Fc --no-owner --no-privileges \
  --schema=financespy \
  -f "$DUMP_PATH"

echo "=== 2. Restoring into Supabase (schema: financespy only, clean, replaces the prior backup) ==="
retry docker exec "$WEB_CONTAINER" pg_restore \
  --no-owner --no-privileges --clean --if-exists \
  -d "$SUPABASE_PG_URL" \
  "$DUMP_PATH"

echo "=== 3. Cleaning up dump file ==="
docker exec "$WEB_CONTAINER" rm -f "$DUMP_PATH"

echo "=== Backup to Supabase completed: $(date) ==="
