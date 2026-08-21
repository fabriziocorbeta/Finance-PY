---
type: synthesis
title: "Migración hosting FinancePY — análisis Cloudflare vs alternativas"
created: 2026-07-16
updated: 2026-07-30
tags:
  - financespy
  - infraestructura
  - hosting
  - decision-pendiente
status: developing
question: "¿Migrar FinancePY de la VM GCP a agents.cloudflare.com? El crédito de Google se acaba."
related:
  - "[[financespy]]"
  - "[[Sesión 2026-07-16 FinancePY security fixes deploy]]"
  - "[[Agente IA CD & Co.]]"
---

# Migración hosting FinancePY — análisis

**Contexto:** crédito GCP por acabarse. Stack actual: VM `alejandro-vm` (us-central1-a, **`e2-standard-4`: 4vCPU/16GB**, confirmado vía `gcloud` el 2026-07-18 — no `e2-micro`/`small` como se podría asumir). DB **ya está afuera** en Supabase → la migración de datos es trivial.

**⚠️ Corrección importante (2026-07-18):** la VM NO es dedicada a FinancePY. `docker images` reveló 3 servicios más corriendo ahí: `n8n` (2.42GB), `alejandro-agent` (2.34GB), `openwa-api`/WhatsApp (2.33GB). Cualquier plan de migración necesita decidir explícitamente qué pasa con esos 3 — moverlos junto con FinancePY, dejarlos en una VM GCP reducida aparte, o migrarlos por separado. El plan Hetzner de abajo (escrito antes de este descubrimiento) asumía que la VM entera se podía apagar al final — **eso ya no es correcto sin antes resolver dónde van esos 3 servicios**.

## Veredicto sobre Cloudflare Agents

**agents.cloudflare.com NO sirve para FinancePY.** Es un SDK para construir agentes de IA sobre Workers + Durable Objects (JS/TS en edge). No ejecuta Ruby/Rails ni contenedores persistentes con Puma + Sidekiq + Redis. Cloudflare Containers (beta) tampoco: sin volúmenes persistentes, diseñado para workloads efímeros, no monolitos.

**Donde SÍ encaja Cloudflare Agents:** el [[Agente IA CD & Co.]] (WhatsApp, Node/TS, pendiente de deploy en Railway). Webhook Meta + llamadas Claude = fit perfecto para Workers: scale-to-zero, free tier generoso. Propuesta: cambiar destino de deploy Railway → Cloudflare (gratis).

## Opciones para la VM Rails

| Opción | Costo/mes | Esfuerzo | Notas |
|---|---|---|---|
| **Hetzner VPS CX22** (2vCPU/4GB) | ~€4.50 | Bajo | ⭐ Recomendada. Mismo docker compose, 1:1, costo fijo |
| Fly.io | ~$5-15 | Medio | PaaS, fly.toml, Redis vía Upstash |
| Railway | ~$10-20 | Bajo-medio | Simple, pricing por uso menos predecible |
| Render | ~$25 | Bajo | web+worker+redis suman; caro |
| Oracle Cloud Always Free | $0 | Medio | ARM (rebuild multi-arch); riesgo reclamo de instancias idle |
| Cloudflare Containers | — | Alto | Descartada: beta, sin persistencia |
| **GCP `southamerica-east1` (São Paulo)** | ~$122-132 (est., no confirmado en calculadora) | Bajo | **En evaluación (2026-07-18).** Mismo `e2-standard-4`, mismo Docker Compose, cero re-arquitectura. Resuelve la causa real de la lentitud medida (latencia Iowa↔Paraguay ~450ms de RTT, no problema de código — ver [[Sesión 2026-07-16 FinancePY security fixes deploy]]). Más caro que Iowa (~$98/mes) y que Hetzner, pero soluciona el problema que originó esta evaluación en primer lugar en vez de solo abaratar. Snapshot+VM nueva+cutover DNS, reversible en cada paso. |

## Plan de migración recomendado (Hetzner, ~1 tarde)

1. Provisionar CX22 (Ashburn o Hillsboro para latencia a us-west Supabase pooler).
2. Instalar docker + docker compose; `git clone` del repo; copiar `.env` de la VM actual.
3. `docker compose -f compose.prod.yml up -d` + certificado (mismo proxy/caddy que uses hoy).
4. Probar con `/etc/hosts` apuntando el dominio a la IP nueva (login, dashboard, sync).
5. Cambiar DNS de `finance.cd-co.com.py` → IP Hetzner (TTL bajo antes).
6. Observar 24-48h → apagar y borrar `alejandro-vm` (fin de gasto GCP).

Cero cambio de código. Rollback trivial: volver el DNS.

## Aclaración Vercel

Vercel se sigue usando pero solo para `cd-co-hub` (frontend JS que comparte repo). FinancePY (Rails) nunca corrió en Vercel. El check "Vercel fail" en los PRs es de ese proyecto JS, no de la app Rails.

## Decisión pendiente

- [ ] Resolver primero: ¿qué pasa con n8n/alejandro-agent/openwa-api? (bloqueante para cualquier plan que apague la VM actual)
- [ ] Confirmar precio real de `southamerica-east1` en la calculadora GCP antes de decidir
- [ ] Elegir entre: (a) Hetzner+Cloudflare (más barato, no resuelve latencia), (b) São Paulo (resuelve latencia, más caro), (c) quedarse + construir PWA (no resuelve el costo, sí la percepción de lentitud)
- [ ] Deploy agente WhatsApp en Cloudflare Agents en vez de Railway (independiente de la decisión anterior)
- [ ] Fecha límite: antes de que se agote el crédito GCP

## 2026-07-30 — Intento Render (costo $0) descartado, pivote a PC local

**Objetivo de la sesión:** bajar costo de hosting a $0 total, sin tocar la DB (Supabase `us-west-2`, proyecto "CD Finanzas" — confirmado con Supabase MCP, NO está en `sa-east-1` como se podría asumir).

**Descartado: Vercel.** Stack Rails+Sidekiq+Postgres no encaja (serverless, sin proceso persistente, sin pgvector nativo). Solo sirve para el frontend JS de [[CD & Co ERP]], nunca para FinancePY.

**Intentado: Render.com free tier.**
- Creada cuenta, conectado repo `cd-co-erp` (rama `main`, mismo repo que comparte con CD&Co ERP).
- Redis (Key Value) gratis desplegado OK: `financespy-redis`, región Oregon (misma que la DB Supabase, para minimizar latencia app↔redis y app↔db).
- **Hallazgo clave:** Background Worker de Render NO tiene tier gratis en la práctica (mínimo real Starter $7/mes), aunque la tabla de pricing pública lo lista como $0 — no aparece como opción al crear el servicio.
- Workaround aplicado: correr web+Sidekiq en el mismo proceso vía `foreman` (`Procfile` nuevo en el repo, gem `foreman` movida del grupo `:development` al grupo default) — commit `d3665aa` en `cd-co-erp`. Válido en teoría para plan $0 con un solo servicio.
- **Bloqueante real encontrado en deploy:** OOM (`Ran out of memory (used over 512MB)`) corriendo Puma (`WEB_CONCURRENCY=2`, cluster mode) + Sidekiq juntos en la instancia free (512MB RAM / 0.1 CPU). Con `WEB_CONCURRENCY=1` probablemente entra, pero deja el margen de memoria mínimo — riesgo real de OOM recurrente en producción con un app financiera real en uso.
- **Decisión (2026-07-30): pivote a correr el servidor en PC local** en vez de seguir con Render free tier — el usuario prefiere esto a pelear con límites de memoria de un free tier ajustado. Deploy a Render quedó a medio terminar (`WEB_CONCURRENCY` sin corregir a 1, no verificado en vivo).

**Estado dejado en el repo `cd-co-erp` (rama `main`):**
- `Procfile` (nuevo): `web: bin/rails server` + `worker: bundle exec sidekiq -c 2` — queda en el repo, no rompe nada localmente ni en la VM actual (compose.prod.yml sigue usando sus propios `command:` por servicio, no lee `Procfile`).
- `Gemfile`: `foreman` movida a top-level (antes solo en `:development`) — inocuo, no agrega peso relevante en producción.
- Commits `aad575d` (fix real: MIME types de fotos en el picker, no relacionado a hosting) y `d3665aa` (Procfile/foreman) ya en `main` y ya deployados en la VM GCP actual — **no requieren revertirse**, son compatibles con seguir en la VM o migrar a PC local.
- En Render quedó creado (pero sin terminar de arreglar): servicio web `cd-co-erp` (Free) + Key Value `financespy-redis` (Free) en el dashboard del usuario. Sin decisión tomada sobre si borrarlos o dejarlos húerfanos — pendiente para la próxima sesión si se abandona Render definitivamente.

**Pendiente real para la migración a PC local (sin arrancar aún):**
- [ ] Definir qué PC (specs, uptime — ¿queda prendida 24/7?, conexión a internet residencial estable, IP)
- [ ] Exponer el server a internet: opciones típicas son Cloudflare Tunnel (gratis, sin abrir puertos en el router) o port-forwarding directo (requiere IP fija o DDNS)
- [ ] DNS: apuntar `finance.cd-co.com.py` al nuevo origen
- [ ] Docker Desktop o Docker Engine en esa PC + mismo `compose.prod.yml` que ya usa la VM (sin cambios de código, DB sigue en Supabase)
- [ ] Definir corte: mantener VM GCP corriendo en paralelo hasta confirmar la PC local estable, luego apagarla
- [ ] Nota de riesgo a discutir con el usuario: una PC hogareña como servidor de producción para una app financiera real tiene downtime/riesgo mucho mayor que cualquier cloud (cortes de luz, reinicios de Windows/macOS, ISP residencial sin SLA) — vale la pena señalarlo aunque la decisión ya esté tomada

## 2026-08-05 — Resuelto el pendiente de arriba: n8n/alejandro-agent/openwa-api van a PC de escritorio dedicada (Ryzen 3, 16GB), no a Railway como primario

**Arquitectura de 3 máquinas confirmada en esta sesión** (responde el checklist pendiente desde el 18/07 sobre qué hacer con los 3 servicios que comparten la VM actual):

| Servicio | Destino | Rol |
|---|---|---|
| FinancePY | Notebook Windows, i5 7ma gen, 8GB RAM, 832GB libres | Primario, dedicada solo a esto |
| n8n + alejandro-agent + openwa-api ([[Agente IA CD & Co]]) | **PC de escritorio separada, Ryzen 3, 16GB RAM** | Primario, dedicada solo a esto |
| Ambos stacks | Railway | Fallback/standby, no primario |

**Pregunta abierta sin confirmar — posible misma máquina que el HP EliteDesk 705 G4 SFF** ya documentado arriba en este archivo (Ryzen 3 PRO 2200G, 16GB, Windows 10 Pro): specs coinciden exactamente (Ryzen 3 + 16GB). Si es la misma PC, ese equipo pasó de candidato para FinancePY (descartado el 04/08 por la corrección de specs de la notebook) a destino confirmado para el stack de Alejandro. **No verificado — falta confirmar con el usuario si es el mismo equipo físico** antes de dar la migración por cerrada.

**Por qué NO todo en la notebook (8GB) ni todo en Railway:**
- Notebook (8GB): FinancePY solo ya deja ~1-2GB de margen real (ver sección 04/08 en [[FinancePY - Hosting fase prueba (PC local)]]). Sumar n8n+agent+openwa (~7GB) reventaría la RAM — swap no compensa porque Alejandro es chat en tiempo real con clientes reales; latencia de swap se traduce en lag visible para el cliente (a diferencia de FinancePY, uso personal tolerante).
- Railway como primario: sigue siendo la opción sin hardware propio, pero con PC dedicada de 16GB ya disponible (costo marginal ~$0 si es hardware que ya se tiene) el costo de oportunidad de pagar Railway 24/7 no se justifica — Railway pasa a rol de fallback ante caída de la PC.

**Con 16GB dedicados a n8n(2.4GB)+alejandro-agent(2.3GB)+openwa-api(2.3GB) (~7GB uso real): sobran ~9GB, sin necesidad de swap para este stack específicamente.**

**Pendiente de definir:** failover automático vs manual si la PC de escritorio cae — automático requiere health check + reconfigurar endpoint del webhook de Meta o proxy inteligente (trabajo de ingeniería real); manual es más simple pero implica downtime hasta que alguien note la caída y redeploye a mano en Railway. Sin decidir aún.

Ver arquitectura técnica de n8n en detalle (dos integraciones separadas, cuál está realmente en producción) en [[Agente IA CD & Co — arquitectura n8n (dos integraciones)]].
