---
type: guide
title: "FinancePY — Guía paso a paso: migrar VM GCP a notebook Windows"
status: lista para ejecutar
created: 2026-08-04
updated: 2026-08-04
tags: [financespy, hosting, infraestructura, guia, windows]
related:
  - "[[FinancePY - Hosting fase prueba (PC local)]]"
  - "[[Migración hosting FinancePY — análisis Cloudflare vs alternativas]]"
  - "[[financespy]]"
---

# FinancePY — Migrar de la VM GCP a la notebook Windows

Guía pensada para ejecutarse **a mano, en el teclado físico de la notebook**
— no por AnyDesk. El control remoto Mac→Windows viene fallando (comandos
que no responden), así que cada paso de acá es autocontenido: copiás/pegás
en una consola de la notebook, sin depender de que el control remoto
funcione bien durante todo el proceso.

**Máquina destino:** notebook Windows, Intel i5 7ma generación, 8GB RAM,
832GB libres. Ver contexto completo y por qué difiere del plan original
(pensado para otra PC) en [[FinancePY - Hosting fase prueba (PC local)]].

**No se toca nada de esto hasta que decidas arrancar.** Los archivos que
usa esta guía (`compose.local.yml`, `Caddyfile.local`,
`docs/cloudflared-config.yml.example`) ya existen en el repo, verificados
hoy. `compose.local.yml` recibió un fix menor hoy (agregar
`EXCHANGE_RATE_PROVIDER`, mismo patrón del bug que rompió el CSS en prod).

## Antes de arrancar: 8GB es justo, no sobra

El cap de Docker para los contenedores es **~2.7GB** (fijo, ya en
`compose.local.yml` — sincronizado 2026-08-04 con el mismo fix de
`WEB_CONCURRENCY=1` que ya resolvió un OOM real durante el intento de
Render, ver [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]]).
Con 8GB totales, Windows + Docker Desktop/WSL2 de fondo se comen el
resto — quedan ~1.5-2.5GB de margen real. Consecuencia práctica:

- Esta notebook queda **dedicada al servidor** mientras dure la prueba —
  no la uses para navegar/oficina al mismo tiempo.
- No abras el navegador con muchas pestañas en la sesión donde corre el
  servidor.
- El fix de OOM (`WEB_CONCURRENCY=1`, límites de memoria por servicio) ya
  viene aplicado de fábrica en `compose.local.yml` — no hace falta
  tocarlo. Si aun así ves reinicios random (`docker compose ps` mostrando
  restarts), bajar `mem_limit: 1536m` → `1200m` en `web` es el siguiente
  paso.

## Paso 0 — Sincronizar fixes a git ✅ hecho (2026-08-04)

Hecho — no hace falta repetir este paso. Para referencia, lo que se
sincronizó a `main` (`fabriziocorbeta/cd-co-erp`) antes de escribir esta
guía:

- `73a5ac0` — fix nonce CSP roto (`session.id` vacío) + `EXCHANGE_RATE_PROVIDER`
  no llegaba al container (los 2 bugs de la sesión de hoy)
- `5f3666f` — `compose.local.yml` sincronizado con el fix de OOM
  (`WEB_CONCURRENCY=1` + límites de memoria) que ya estaba en
  `compose.prod.yml` desde el 30/07 pero nunca se había portado al
  archivo que usa esta migración

De paso se encontró que ese fix de OOM del 30/07 **tampoco se había
desplegado nunca a la VM actual** (quedó commiteado en GitHub, la VM
nunca hizo `git pull` desde entonces) — la VM real corrió sin él todo
este tiempo. No se tocó la VM corriendo hoy para no sumar otro
redeploy no pedido en la misma sesión; queda como decisión aparte si
querés que también lo aplique ahí.

## Paso 1 — Instalar WSL2 + Docker Desktop (en la notebook, PowerShell como administrador)

```powershell
wsl --install
```

Reiniciar cuando lo pida. Después instalar **Docker Desktop for Windows**
desde docker.com/products/docker-desktop (usa el motor WSL2 por default,
no tocar nada en el instalador). Abrirlo una vez y confirmar que dice
"Docker Desktop is running" antes de seguir.

Configurar Docker Desktop para arrancar solo con Windows:
Settings → General → **"Start Docker Desktop when you log in"** ✅

## Paso 2 — Clonar el repo (en la terminal Ubuntu/WSL2 que instaló el paso 1)

El repo es **privado** y GitHub no acepta usuario/contraseña para git
desde 2021 — hace falta un token o `gh` CLI. La opción más confiable dado
que el problema es el input de comandos por AnyDesk (no la pantalla, que
sí se ve) es el **device flow de `gh`**: corre un comando, muestra un
código corto en pantalla, y autorizás desde el navegador de la Mac — no
depende de tipear nada largo ni pegar tokens a través del control remoto.

```bash
# Instalar gh CLI (Ubuntu/WSL2):
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh -y

gh auth login
# Elegir: GitHub.com → HTTPS → "Login with a web browser"
# Va a mostrar un código de 8 caracteres — anotalo (se ve en pantalla
# aunque el input falle) y entralo en github.com/login/device desde
# CUALQUIER navegador (el de la Mac sirve, no hace falta que sea en la
# notebook)

gh repo clone fabriziocorbeta/cd-co-erp financespy
cd financespy
git checkout main
```

## Paso 3 — Variables de entorno

```bash
cp .env.production.example .env.local
```

Editar `.env.local` (`nano .env.local`) y completar **vos mismo** (son
credenciales, no te las escribo ni las manejo yo):

- `SECRET_KEY_BASE` — generar nueva con `openssl rand -hex 64`, **no
  reutilices** la de la VM actual (son independientes por diseño)
- `DATABASE_URL` — la misma que usa la VM hoy (mismo Supabase, mismo
  schema `financespy`). Copiala del `.env` de la VM vía AnyDesk **file
  transfer** (no por teclado remoto — esa función de AnyDesk no depende
  del control de comandos que viene fallando) o pasala por USB.
- `ANTHROPIC_API_KEY`, `OPENAI_ACCESS_TOKEN` (si lo usás) — mismo criterio
  que `DATABASE_URL`.
- Agregar una línea que el template todavía no tiene:
  `EXCHANGE_RATE_PROVIDER=yahoo_finance`
- Dejar `CSP_REPORT_ONLY=true` para el primer arranque (así si algo se
  configuró mal no te rompe la UI mientras probás) — lo pasás a `false`
  recién en el Paso 6, cuando ya viste que carga bien.

## Paso 4 — Levantar el stack

```bash
docker compose -f compose.local.yml --env-file .env.local up -d --build
```

La primera vez tarda (build de la imagen Rails). Verificar:

```bash
docker compose -f compose.local.yml ps
curl -H "Host: finance.cd-co.com.py" http://localhost:8080
```

El `curl` debería devolver HTML (probablemente un 302 al login, igual que
en prod) — **no** un error de conexión.

## Paso 5 — Cloudflare Tunnel ✅ ya creado, solo falta copiarlo (2026-08-04)

El túnel **ya está creado** (desde la VM, que ya tenía el certificado de
cuenta autorizado por el tunnel existente de n8n/agente — no hizo falta
repetir el login OAuth):

- Nombre: `financespy-local`
- ID: `3c395573-45f7-4313-8c8b-a37e924517e6`
- Archivos generados en la VM: `~/.cloudflared/3c395573-45f7-4313-8c8b-a37e924517e6.json`
  (credenciales — **secreto**, es la clave privada del túnel) y
  `~/.cloudflared/financespy-notebook-config.yml` (config, ya apunta a
  `http://localhost:8080`, mismo puerto de `Caddyfile.local`)

Instalar `cloudflared` en la notebook (WSL2/Ubuntu):

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
mkdir -p ~/.cloudflared
```

Copiar **los 2 archivos** de la VM a `~/.cloudflared/` de la notebook —
por **AnyDesk file transfer** (no por teclado remoto, esa función no
depende del input que viene fallando) o USB, mismo criterio que
`DATABASE_URL`. Si el usuario de WSL2 en la notebook no se llama
`Fabrizio`, abrir `financespy-notebook-config.yml` y corregir la ruta de
`credentials-file` para que apunte donde realmente quedó el `.json`.

Probar el túnel **sin todavía tocar el DNS público**:

```bash
cloudflared tunnel --config ~/.cloudflared/financespy-notebook-config.yml run
```

Si loguea "Registered tunnel connection" sin errores, el túnel funciona.
Dejarlo corriendo como servicio:

```bash
sudo cloudflared --config ~/.cloudflared/financespy-notebook-config.yml service install
```

## Paso 6 — Corte real (el único paso que no es reversible al instante)

Todavía nada de esto es visible desde afuera — `finance.cd-co.com.py`
sigue apuntando a la VM GCP. Recién acá se corta:

```bash
cloudflared tunnel route dns financespy-local finance.cd-co.com.py
```

Esto reemplaza el registro DNS actual (A record → IP de la VM) por un
CNAME al túnel. Propagación casi instantánea (Cloudflare, TTL bajo).
Verificar desde la Mac:

```bash
curl -sv https://finance.cd-co.com.py/ 2>&1 | grep -i 'via:'
```

Si dice `via: 1.1 Caddy` sigue siendo la VM (cache/propagación); esperar
1-2 min y repetir. Una vez que responde desde el túnel, entrar al
dashboard normal y confirmar que carga bien — ahí (y solo ahí) cambiar
`CSP_REPORT_ONLY=false` en `.env.local` y:

```bash
docker compose -f compose.local.yml --env-file .env.local up -d --force-recreate web worker
```

## Paso 7 — Dejar la VM de guardia, no apagarla todavía

Según el plan original, la VM GCP se apaga recién cuando la notebook
demuestra estabilidad. Dejarla prendida (sin tráfico real, ya que el DNS
apunta a la notebook) **24-48h mínimo** como rollback: si algo falla,
revertir el paso 6 es solo volver a correr `cloudflared tunnel route dns`
apuntando al registro anterior, o simplemente borrar el CNAME y recrear el
A record hacia `34.170.196.91`.

## Paso 8 — Que la notebook no se duerma ni se apague sola

En Windows: Configuración → Sistema → Energía y batería → Pantalla y
suspensión → **"Nunca"** tanto para "cuando está enchufada" como (si vas a
dejarla con batería de respaldo) para "con batería". Si es notebook con
tapa: Panel de Control → Opciones de energía → "Elegir el comportamiento
del botón de cierre de tapa" → **"No hacer nada"**.

Windows Update: Configuración → Windows Update → Opciones avanzadas →
desactivar reinicio automático fuera de horario, o programarlo para una
franja donde puedas verificar que todo volvió a levantar después (los
`restart: unless-stopped` de Docker levantan los contenedores solos al
reiniciar Docker Desktop, pero **solo si Docker Desktop arrancó** — de ahí
el Paso 1 de dejarlo en inicio de sesión).

## Checklist rápido

- [x] Paso 0 — fixes sincronizados a git (`73a5ac0`, `5f3666f`) — hecho 2026-08-04
- [ ] Paso 1 — WSL2 + Docker Desktop instalados, arranca con Windows
- [ ] Paso 2 — repo clonado, rama `main`
- [ ] Paso 3 — `.env.local` completo (vos cargás las credenciales)
- [ ] Paso 4 — `docker compose up` OK, `curl localhost:8080` responde
- [x] Paso 5a — túnel `financespy-local` creado en Cloudflare — hecho 2026-08-04
- [ ] Paso 5b — 2 archivos copiados a la notebook, `cloudflared ... run` sin error
- [ ] Paso 6 — DNS cortado, dashboard verificado, CSP a `false`
- [ ] Paso 7 — VM GCP en pie 24-48h como rollback antes de apagarla
- [ ] Paso 8 — notebook configurada para no dormir/reiniciar sola
