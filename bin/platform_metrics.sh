#!/usr/bin/env bash
# Records (idempotently) the owner-facing aggregate for one day (default: today):
# total absolute amount registered per currency + number of active families.
# No per-family / per-user data is stored or printed.
#
#   LOCAL_ADMIN_DATABASE_URL=<superuser url> bin/platform_metrics.sh [YYYY-MM-DD]
#
# Cron example (notebook): 55 23 * * * ... bin/platform_metrics.sh >> log/platform_metrics.log 2>&1
set -euo pipefail

: "${LOCAL_ADMIN_DATABASE_URL:?LOCAL_ADMIN_DATABASE_URL is required (admin role, bypasses RLS)}"
PSQL="${PSQL:-psql}"   # e.g. PSQL="docker exec -i financespy-web-1 psql" when psql is not on the host
DB_URL="${LOCAL_ADMIN_DATABASE_URL%%\?*}"
DAY="${1:-$(date +%F)}"
[[ "$DAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "bad date: $DAY" >&2; exit 1; }

$PSQL "$DB_URL" -v ON_ERROR_STOP=1 -v day="$DAY" <<'SQL'
SET search_path TO financespy, public;
INSERT INTO platform_daily_metrics (date, currency, total_volume, entries_count, active_families, created_at, updated_at)
SELECT :'day'::date, e.currency, SUM(ABS(e.amount)), COUNT(*), COUNT(DISTINCT a.family_id), NOW(), NOW()
FROM entries e
JOIN accounts a ON a.id = e.account_id
WHERE e.entryable_type = 'Transaction'
  AND e.excluded = false
  AND e.currency IS NOT NULL
  AND e.created_at::date = :'day'::date
GROUP BY e.currency
ON CONFLICT (date, currency) DO UPDATE
  SET total_volume = EXCLUDED.total_volume,
      entries_count = EXCLUDED.entries_count,
      active_families = EXCLUDED.active_families,
      updated_at = NOW();

-- What the owner looks at: lifetime total per currency + last 7 days activity.
SELECT currency,
       SUM(total_volume) AS total_registrado,
       SUM(total_volume) FILTER (WHERE date > current_date - 7) AS ultimos_7_dias,
       MAX(active_families) FILTER (WHERE date > current_date - 7) AS max_familias_activas_dia
FROM platform_daily_metrics GROUP BY currency ORDER BY currency;
SQL
