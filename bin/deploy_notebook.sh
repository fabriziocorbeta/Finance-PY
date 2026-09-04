#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# FinancePY — Notebook Deployment Script
# Target: Single-command deployment script to run on local notebook via SSH.
#
# Steps performed:
# 1. Pull latest changes from main (git pull --ff-only)
# 2. Build web & worker containers passing BUILD_COMMIT_SHA
# 3. Run pending migrations against the new image
# 4. Start containers detached (docker compose up -d web worker)
# 5. CRITICAL: Restart Caddy container to flush stale container IP cache
# 6. Verify /up endpoint status 200 and verify /internal/version SHA match
# =====================================================================

# compose.local.yml + .env.local is what actually runs in production (confirmed
# via `docker inspect ... com.docker.compose.project.config_files`) - compose.prod.yml
# is unused. Caddy listens on local port 8080, not 80.
COMPOSE_FILE="${COMPOSE_FILE:-compose.local.yml}"
ENV_FILE="${ENV_FILE:-.env.local}"
CADDY_CONTAINER="${CADDY_CONTAINER:-financespy-caddy-1}"
PROD_URL="${PROD_URL:-http://localhost:8080}"

COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

echo "=== 1. Pulling latest main branch ==="
git pull --ff-only

CURRENT_HEAD=$(git rev-parse HEAD)
echo "Current HEAD commit SHA: $CURRENT_HEAD"

echo "=== 2. Building Docker containers (web, worker) ==="
BUILD_COMMIT_SHA="$CURRENT_HEAD" "${COMPOSE[@]}" build web worker

echo "=== 3. Running pending migrations ==="
"${COMPOSE[@]}" run --rm web bin/rails db:migrate

echo "=== 4. Starting updated services ==="
"${COMPOSE[@]}" up -d web worker

echo "=== 5. CRITICAL: Restarting Caddy container ($CADDY_CONTAINER) ==="
echo "Flushing Caddy proxy IP cache to avoid 502 Bad Gateway errors..."
docker restart "$CADDY_CONTAINER" || {
  echo "::warning:: Failed to restart $CADDY_CONTAINER. Trying fallback 'caddy' container..."
  "${COMPOSE[@]}" restart caddy || true
}

echo "=== 6. Running health checks ==="
# Fixed 5s sleep was too short on this notebook (WSL2, 8GB host, RAM tight
# under concurrent Docker builds) -- Rails cold boot has taken 15-20s+ during
# this session's real deploys, so a single early check reported a false
# "failed" on a deploy that was actually fine a few seconds later. Poll
# instead: up to HEALTHCHECK_TIMEOUT (default 60s), checking every 3s.
HEALTHCHECK_TIMEOUT="${HEALTHCHECK_TIMEOUT:-60}"
elapsed=0
UP_STATUS="000"
while [ "$elapsed" -lt "$HEALTHCHECK_TIMEOUT" ]; do
  UP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$PROD_URL/up" || echo "000")
  if [ "$UP_STATUS" = "200" ]; then
    break
  fi
  sleep 3
  elapsed=$((elapsed + 3))
  echo "Waiting for Rails to initialize... (${elapsed}s / ${HEALTHCHECK_TIMEOUT}s, last status: $UP_STATUS)"
done

if [ "$UP_STATUS" = "200" ]; then
  echo "✅ Health check passed: GET /up returned 200 OK (after ${elapsed}s)"
else
  echo "❌ Health check failed: GET /up returned HTTP $UP_STATUS after ${HEALTHCHECK_TIMEOUT}s"
  exit 1
fi

if [ -n "${INTERNAL_VERSION_TOKEN:-}" ]; then
  echo "Checking /internal/version endpoint..."
  DEPLOYED_JSON=$(curl -s -H "X-Internal-Token: $INTERNAL_VERSION_TOKEN" "$PROD_URL/internal/version" || echo "")
  DEPLOYED_SHA=$(echo "$DEPLOYED_JSON" | grep -o '"commit_sha":"[^"]*"' | cut -d'"' -f4 || echo "")

  if [ "$DEPLOYED_SHA" = "$CURRENT_HEAD" ]; then
    echo "✅ Version check passed: Deployed SHA matches HEAD ($CURRENT_HEAD)"
  else
    echo "⚠️ Version mismatch: Deployed SHA is '$DEPLOYED_SHA', expected '$CURRENT_HEAD'"
  fi
else
  echo "ℹ️ INTERNAL_VERSION_TOKEN not set in environment; skipping version verification."
fi

echo "=== 🚀 Deployment completed successfully! ==="
