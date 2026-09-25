# Runbook — deploy y rollback de compose.local.yml

Este runbook cubre el compose que corre HOY en la notebook de producción
(`compose.local.yml` + `.env.local`, ver cabecera de ese archivo). Requiere
acceso físico/SSH-Tailscale al host — nada de esto se ejecuta desde acá.

> **Nota de scope (E9):** `docs/DEPLOY_CHECKLIST.md` describe un flujo de
> deploy distinto contra `compose.prod.yml` (sin Postgres/Redis locales,
> apunta a Supabase). Los dos composes coexisten en el repo. Este runbook es
> específico de `compose.local.yml`, que es el que la cabecera del archivo y
> la tarea E9 identifican como el que corre en prod hoy. Verificar con el
> coordinador cuál de los dos está realmente detrás de Cloudflare Tunnel
> antes de aplicar nada — no se pudo confirmar desde este worktree (sin
> acceso al host).

## 0. Antes de la primera vez que se agrega REDIS_PASSWORD

Este compose ahora exige `REDIS_PASSWORD` y `POSTGRES_LOCAL_USER`/
`POSTGRES_LOCAL_PASSWORD` en `.env.local` (antes solo los dos últimos eran
obligatorios). Si `.env.local` ya existe en el host y no tiene
`REDIS_PASSWORD`, `docker compose up` va a fallar con un error claro
("REDIS_PASSWORD requerido...") en vez de arrancar con Redis sin auth. Orden
exacto para no tener downtime sorpresa:

```bash
cd ~/financespy   # o el path real del checkout en el host
grep -q '^REDIS_PASSWORD=' .env.local || {
  echo "REDIS_PASSWORD=$(openssl rand -hex 32)" >> .env.local
}
```

Con eso en `.env.local`, seguir con el deploy normal (paso 1 en adelante).
Sin este paso, `docker compose -f compose.local.yml up -d` se niega a
levantar `redis`, `web` y `worker` (los tres leen `REDIS_PASSWORD` a través
del anchor `x-rails-env` / el propio comando de `redis-server`) — `postgres`
y `caddy` sí levantan igual, así que el fallo es parcial y confuso si no se
sigue este orden.

## 1. Deploy normal (después del paso 0, o si ya está `REDIS_PASSWORD`)

```bash
cd ~/financespy
git pull --ff-only
docker compose -f compose.local.yml --env-file .env.local config -q   # valida sintaxis antes de tocar nada
docker compose -f compose.local.yml --env-file .env.local pull        # trae postgres/redis/caddy por digest fijo — no deberían cambiar nunca solos
BUILD_COMMIT_SHA=$(git rev-parse HEAD) \
  docker compose -f compose.local.yml --env-file .env.local up -d --build
```

`depends_on: condition: service_healthy` hace que Compose espere a que
`postgres`/`redis` pasen su healthcheck antes de arrancar `web`/`worker`, y a
que `web` pase el suyo antes de arrancar `caddy` — no hace falta el
`docker restart caddy` manual que sí necesita `compose.prod.yml`
(`docs/DEPLOY_CHECKLIST.md`) porque acá todos los servicios están en la
misma red bridge de Compose (`financespy_net`) resuelta por nombre de
servicio, no por IP cacheada.

### Verificación post-deploy

```bash
docker compose -f compose.local.yml ps                 # las 5 filas en "healthy", no solo "running"
curl -sf http://localhost:8080/up && echo OK            # a través de Caddy
docker compose -f compose.local.yml logs --tail 50 worker | grep -i sidekiq
```

Si alguna fila queda en `starting` más de ~60s o pasa a `unhealthy`, ver
`docker compose -f compose.local.yml logs <servicio>` antes de reintentar —
no hacer `up -d` en loop.

## 2. Rollback

Los datos (Postgres, Redis AOF, storage) viven en volúmenes nombrados
(`postgres-data`, `redis-data`, `app-storage`) que un rollback de código NO
toca — solo se recrean los contenedores `web`/`worker` con la imagen del
commit anterior.

```bash
cd ~/financespy
git log --oneline -5                    # identificar el commit bueno anterior
git checkout <commit-sha-anterior>
BUILD_COMMIT_SHA=<commit-sha-anterior> \
  docker compose -f compose.local.yml --env-file .env.local up -d --build web worker
git checkout main                       # volver a la rama, sin perder el estado de los contenedores
```

Si el rollback es por una migración que ya corrió (el entrypoint las corre
solas al boot, ver cabecera de este compose y `bin/docker-entrypoint`) y
rompió el boot en loop:

1. `docker compose -f compose.local.yml logs web | tail -80` para confirmar que es la migración.
2. Revertir el commit de la migración (no solo el checkout) y rebuildear como arriba — el entrypoint no hace rollback automático de esquema.
3. Si la migración ya escribió datos incompatibles, es un caso manual: parar `web`+`worker`, restaurar desde el backup cifrado más reciente (`bin/backup_encrypted.sh` / `docs/ops/backup-role.sql`), recién ahí levantar de nuevo.

## 3. Rollback de la imagen `caddy:2-alpine` pineada por digest

Si el digest pineado resulta tener un bug (poco probable, pero el pin
también congela bugs), el fallback es volver a un digest anterior conocido
o, temporalmente, a `caddy:2-alpine` sin pin (menos seguro, solo como
puente) mientras se resuelve el digest bueno con:

```bash
# Requiere Docker local (no disponible en este worktree de desarrollo)
docker buildx imagetools inspect caddy:2-alpine
```

## 5. Backup con rol sin superusuario

Una vez corrido `docs/ops/backup-role.sql` contra la base real (ver
comentario de cabecera de ese archivo para el tradeoff BYPASSRLS), apuntar
`LOCAL_ADMIN_DATABASE_URL` de `bin/backup_encrypted.sh` al nuevo rol en vez
del admin/superusuario actual:

Armar `LOCAL_ADMIN_DATABASE_URL` a partir de estas partes (no pegar la URL
completa en ningún archivo versionado, solo en el `.env.local` del host):

- esquema: `postgresql`
- usuario: `financespy_backup`
- password: la que se le asignó al rol en `docs/ops/backup-role.sql`
- host/puerto: `localhost` / `5432`
- base: `financespy`
- query param: `schema_search_path=financespy`

```bash
BACKUP_GPG_RECIPIENT=<fingerprint> bin/backup_encrypted.sh
```

No se modificó `bin/backup_encrypted.sh` en este cambio (fuera del scope de
archivos de E9) — queda como paso manual de config del cron/systemd timer
que lo dispara en el host, que tampoco se pudo ubicar desde este worktree
(no hay `.service`/`.timer`/crontab versionado en el repo).

## 6. Validación sin Docker local (usada para este cambio)

Este worktree no tiene Docker instalado, así que `compose.local.yml` se
validó como YAML puro (no valida el schema de Compose, solo que parsea):

```bash
ruby -ryaml -e 'YAML.load_file("compose.local.yml", aliases: true); puts "YAML OK"'
```

En el host, antes de aplicar, correr la validación real:

```bash
docker compose -f compose.local.yml --env-file .env.local config -q
```
