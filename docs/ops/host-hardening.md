# Runbook — hardening del host (notebook WSL2/Ubuntu)

Todo esto se aplica en el HOST (dentro de WSL2, no en un contenedor). Nada de
esto se pudo ejecutar ni verificar desde este worktree (sin acceso al host,
sin SSH/Tailscale acá) — son pasos a correr manualmente por el coordinador.
Se pusieron en `docs/ops/` para que quede versionado en el repo en vez de
vivir solo en la memoria de quien lo hizo la primera vez.

## 1. Rotación de logs de Docker (`/etc/docker/daemon.json`)

**Por qué:** sin esto, el log driver default de Docker (`json-file`) no
rota — los logs de `web`/`worker`/`redis`/`postgres`/`caddy` crecen sin
límite. En una notebook con 8GB reales y WSL2 topeado a 4GB
(`compose.local.yml`, comentario de cabecera), un log sin rotar es un vector
de "se llenó el disco a las 3am" además de gasto de RAM/IO.

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker   # o: reiniciar Docker Desktop si es ese el motor en WSL2
```

**Importante:** `log-opts` en `daemon.json` es el default para contenedores
NUEVOS — no rota retroactivamente los logs de los contenedores ya corriendo.
Después de aplicar esto, el próximo `docker compose up -d --build` (que
recrea `web`/`worker`) ya toma la config nueva; `redis`/`postgres`/`caddy`
también quedan cubiertos porque el runbook de deploy los recrea con `pull` +
`up -d`. Verificar con:

```bash
docker inspect financespy-web-1 --format '{{json .HostConfig.LogConfig}}'
```

## 2. `unattended-upgrades` en la WSL

**Por qué:** WSL2 no tiene un ciclo de parches automático como Windows —
queda 100% a criterio de quien entra a actualizar manualmente. Dado que esta
notebook corre producción expuesta vía Cloudflare Tunnel, un CVE de kernel
Ubuntu/OpenSSL/etc sin parchear es ventana abierta.

```bash
sudo apt-get update
sudo apt-get install -y unattended-upgrades apt-listchanges
sudo dpkg-reconfigure -plow unattended-upgrades   # responder "Yes" al prompt
```

Confirmar que solo actualiza parches de seguridad (no arrastra un upgrade
mayor de paquete que rompa algo en caliente) revisando
`/etc/apt/apt.conf.d/50unattended-upgrades` — la línea
`Unattended-Upgrade::Allowed-Origins` debe tener solo los orígenes
`${distro_id}:${distro_codename}-security` (viene así por default en Ubuntu,
no tocar salvo que alguien lo haya cambiado).

**Caveat específico de WSL2:** `unattended-upgrades` normalmente depende de
un timer de systemd (`apt-daily-upgrade.timer`), y WSL2 solo corre systemd
si `[boot] systemd=true` está en `/etc/wsl.conf` (y la distro se reinició
con `wsl --shutdown` después de setearlo) — si no, el timer nunca dispara.
Verificar antes de asumir que quedó anda solo:

```bash
systemctl is-system-running   # si da error "not running", systemd no está activo en esta WSL
systemctl list-timers | grep apt-daily
```

Si systemd no está activo, la alternativa es un cron job explícito
(`sudo crontab -e` → `0 4 * * * unattended-upgrade -d >> /var/log/unattended-upgrades-cron.log 2>&1`)
en vez de depender del timer.

## 3. `pg_hba.conf`: trust → scram-sha-256

**Estado verificado en el repo (no en el host):** no hay ningún
`POSTGRES_HOST_AUTH_METHOD` ni init script custom en `compose.local.yml`
antes de este cambio (grep sobre el repo, `compose.local.yml:139-157` en la
versión previa) — la imagen oficial `postgres:17` ya configura, desde el
cambio de default en el proyecto docker-library/postgres (~2022),
`scram-sha-256` para conexiones por TCP/host y `trust` solo para el socket
Unix local dentro del propio contenedor (que nada externo puede alcanzar, ya
que ese socket no se expone fuera del contenedor). Es decir: **la premisa de
la tarea ("pg_hba en trust") no se pudo confirmar contra el `pg_hba.conf`
real del host** — solo se pudo verificar que el repo no lo fuerza a `trust`.
Falta confirmar en el host mismo:

```bash
# Dentro del contenedor postgres corriendo:
docker exec financespy-postgres-1 cat /var/lib/postgresql/data/pg_hba.conf | grep -v '^#' | grep -v '^$'
```

Si la línea `host all all all ...` dice `trust` en vez de `scram-sha-256`,
es porque el volumen `postgres-data` se inicializó ANTES de que la imagen
cambiara su default, o con un `POSTGRES_HOST_AUTH_METHOD=trust` explícito en
algún momento pasado. `POSTGRES_HOST_AUTH_METHOD`/`POSTGRES_INITDB_ARGS`
(agregados a `compose.local.yml` en este cambio) **solo aplican en un
`initdb` sobre un volumen vacío** — en un volumen ya inicializado no hacen
nada. Para corregir un volumen existente sin perder datos (recrearlo
destruiría Postgres):

```bash
# 1. Backup primero (bin/backup_encrypted.sh o docs/ops/backup-role.sql)
# 2. Editar pg_hba.conf a mano dentro del contenedor (o vía volumen montado)
docker exec -it financespy-postgres-1 bash -c \
  "sed -i 's/^host all all all trust/host all all all scram-sha-256/' /var/lib/postgresql/data/pg_hba.conf"
# 3. Verificar que todos los roles (financespy_app, financespy_backup si ya existe,
#    el POSTGRES_USER admin) tengan password scram seteado -- si algún rol se
#    creó bajo "trust" puede que nunca haya tenido password real:
docker exec -it financespy-postgres-1 psql -U "$POSTGRES_LOCAL_USER" -d financespy -c \
  "SELECT rolname, rolpassword IS NOT NULL AS has_password FROM pg_authid;"
# 4. Recargar config (no requiere reiniciar el contenedor ni cortar conexiones activas):
docker exec -it financespy-postgres-1 psql -U "$POSTGRES_LOCAL_USER" -d financespy -c "SELECT pg_reload_conf();"
# 5. Probar una conexión nueva del lado app ANTES de dar por cerrado -- un
#    pg_hba mal editado puede dejar a `web`/`worker` sin poder reconectar.
```

Si algún rol no tiene password scram seteado (paso 3 da `has_password =
f`), hay que setearlo (`ALTER ROLE ... WITH PASSWORD '...'`) antes del paso
4, o esas conexiones empiezan a fallar apenas se recargue la config.

## 4. Rol de respaldo sin superusuario

Ver `docs/ops/backup-role.sql` (SQL idempotente) y la sección "Backup" de
`docs/ops/deploy-runbook.md` para el rol `financespy_backup`.
