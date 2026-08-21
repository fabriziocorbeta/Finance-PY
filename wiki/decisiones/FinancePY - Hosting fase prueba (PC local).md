---
type: decision
title: "FinancePY — Hosting fase de prueba en PC local"
status: propuesto
created: 2026-07-18
updated: 2026-08-05
tags: [financespy, hosting, infraestructura, decision]
---

# FinancePY — Hosting fase de prueba (PC local en vez de VM GCP)

## Contexto

FinancePY (fork del proyecto upstream open-source, Rails 7.2) está en fase de prueba: varios meses de testing
con pocos usuarios, **no comercial todavía**. Recién al validar el producto
pasa a comercializarse. La VM actual (e2-standard-4, GCP us-central1-a, Iowa)
corre además n8n/alejandro-agent/openwa-api — no es exclusiva de FinancePY, y
tiene costo mensual + latencia geográfica alta hacia Paraguay (~200ms
confirmado por logs).

Pregunta: ¿usar la PC de casa (HP EliteDesk 705 G4 SFF) para hostear
FinancePY durante la fase de prueba, y así bajar costo a cero mientras se
valida el producto?

## Specs de la PC

| Componente | Detalle |
|---|---|
| CPU | AMD Ryzen 3 PRO 2200G, 4 núcleos, 3.50 GHz |
| RAM | 16 GB (14.9 GB utilizable) |
| GPU | Radeon Vega 8 integrada (no relevante para esto) |
| SO | Windows 10 Pro 22H2 |
| Modelo | HP EliteDesk 705 G4 SFF |

Specs alcanzan de sobra para Rails + Postgres con tráfico bajo (pocos
usuarios de prueba). El cuello de botella no es hardware, es el contexto de
uso: PC doméstica, uso diario mixto, Windows, internet residencial.

## Decisión: viable para esta fase, no para comercial

### Por qué SÍ sirve ahora (fase de prueba, no comercial)

- Uptime imperfecto es aceptable — no hay cliente pagando con expectativa de SLA
- Sin contrato de disponibilidad que cumplir
- ISP residencial: mientras no sea servicio público a escala, no genera fricción
- Corta el costo de la VM a $0 mientras dura la validación

### Por qué NO sirve cuando pase a comercial

- Sin SLA real, sin redundancia, sin garantía de uptime frente a clientes pagos
- IP dinámica / dependencia de la red doméstica
- Windows no es plataforma de server de producción
- Cortes de luz/internet de la casa tumban el servicio para terceros pagando

**Plan de dos fases:**
1. **Ahora (prueba, meses):** PC local (FinancePY) + Railway (agentes) + Cloudflare Tunnel. **VM GCP se desactiva por completo** — sin costo residual
2. **Al comercializar:** migrar FinancePY a cloud con SLA (São Paulo southamerica-east1, ~$122-132/mes est., resuelve latencia real); agentes se quedan en Railway o se reevalúa según escala

### Rol de la VM: desactivación total

La VM GCP (e2-standard-4, Iowa) se apaga/elimina — Railway reemplaza su
función para los agentes, y la PC local reemplaza su función para
FinancePY. No queda como fallback de guardia:

- Corta el 100% del costo de la VM, no una porción reducida
- Sin dependencia residual de GCP durante la fase de prueba
- **Fallback de FinancePY: Railway**, no la VM. Si la PC de casa cae (luz/
  internet), se levanta una instancia de FinancePY en Railway apuntando al
  **mismo `DATABASE_URL` de Supabase** — no hay restore de backup que hacer,
  la data ya vive ahí (más simple de lo pensado originalmente, ver
  corrección en la sección de Backups)
- Railway concentra entonces dos roles: primario para los agentes
  (n8n/alejandro-agent/openwa-api) y standby/fallback para FinancePY
- Implica sumar el costo de mantener esa instancia de respaldo (mínima,
  apagada o "sleep" hasta necesitarla) al estimado de Railway — ver
  sección de costos más abajo
- Activar el fallback es solo: desplegar el mismo repo en Railway con las
  mismas env vars de `.env.production.example` — sin pasos de restore de DB

## Aislamiento de recursos (Docker)

**Corrección importante:** FinancePY usa Postgres gestionado en **Supabase**
(mismo `DATABASE_URL` que prod, proyecto "CD Finanzas", schema `financespy`)
— no hay Postgres corriendo local. El stack real es `caddy` + `web` + `worker`
(Rails/Sidekiq) + `redis`, tal como en `compose.prod.yml`.

Archivo real ya armado: [`compose.local.yml`](../../compose.local.yml) en el
repo `financespy`, con límites aplicados:

| Servicio | RAM | CPU |
|---|---|---|
| web (Rails) | 2g | 1.5 |
| worker (Sidekiq) | 768m | 0.75 |
| redis | 256m | 0.25 |
| caddy | 128m | 0.25 |
| **Total** | **~3.1GB** | **~2.75** |

Notas:
- Usa `mem_limit`/`cpus` (formato standalone), no `deploy.resources` —
  ese bloque solo aplica en modo Swarm y se ignora en `docker-compose` normal
- Si Rails/Sidekiq llegan al techo de RAM, el OOM-killer mata el proceso
  **dentro del contenedor** — no afecta a Windows ni al resto de la PC
- `cpu_shares` bajo (512) en web/worker = en contención, el host (uso normal
  de la persona) gana prioridad; si nadie usa la PC, Docker puede usar más
- Con 4 núcleos totales, ~2.75 cores cap deja margen real
- Corre sobre WSL2 (Ubuntu vía `wsl --install`, no instalación de SO aparte)
  + Docker Desktop — mejor rendimiento y evita fricción de gems nativas de Rails
- `Caddyfile.local` simplificado (sin bloque ACME/dominio) porque Cloudflare
  Tunnel maneja el HTTPS público — Caddy solo hace reverse proxy interno en
  `:8080` + headers de seguridad

## ¿Se puede sumar también alejandro-agent (n8n/openwa-api) a la PC?

Pregunta evaluada: subir el cap de Docker a 6GB, ¿alcanza para correr los
agentes (n8n + alejandro-agent + openwa-api, que responden a clientes reales
del negocio) en la PC local sin afectar el uso normal?

**Presupuesto de RAM (16 GB físicos totales):**

| Reservado | RAM |
|---|---|
| Windows + uso normal (navegador, Office, etc.) | 4-6 GB |
| Docker — agentes (n8n+alejandro-agent+openwa, cap 6GB) | 6 GB |
| Libre / margen | 4-6 GB |

**Solo agentes (sin FinancePY corriendo a la vez):** viable con cap de 6GB.
openwa (Chromium headless para WhatsApp Web) es lo más pesado del combo;
6GB da margen para n8n + agent + openwa + colchón razonable.

**Agentes + FinancePY al mismo tiempo:** no recomendado en los 16GB
actuales — 6GB (agentes) + 4GB (FinancePY) = 10GB Docker + 4-6GB Windows =
14-16GB de 16GB totales. Cero margen real, riesgo de swap y lentitud
perceptible para quien usa la PC a diario.

**Mitigaciones:**
1. **No correr ambos stacks a la vez** — agentes en PC + FinancePY en VM
   (o viceversa), usando el rol de fallback descrito arriba para alternar
2. **Upgrade físico de RAM** — HP EliteDesk 705 G4 SFF soporta hasta 32GB
   según specs del fabricante; agregar un módulo (ej. +16GB) resuelve el
   problema de raíz y permite correr todo junto con margen amplio
3. Dado que alejandro-agent responde a **clientes reales de un negocio
   activo** (no es fase de prueba como FinancePY), conviene priorizar su
   estabilidad — si hay que elegir qué se queda en la PC y qué en la VM,
   los agentes de cara a cliente deberían quedar en el entorno más estable

## Decisión agentes: Railway (no Cloudflare, no PC local)

Se evaluó Cloudflare (Agents SDK/Workers) vs Railway (contenedores Docker)
para n8n + alejandro-agent + openwa-api. **Railway gana por restricción
técnica dura, no por preferencia:**

- openwa-api requiere sesión persistente de WhatsApp Web vía Chromium
  headless — Cloudflare Workers (V8 Isolates) no soporta procesos
  long-lived de ese tipo; su Browser Rendering API es para renders
  puntuales, no sesiones 24/7
- n8n está diseñado como servicio Docker continuo, no función event-driven
- Se necesita Postgres/Redis persistentes nativos — encaja con el modelo
  de Railway, no con Durable Objects/D1

Cloudflare quedaría como opción válida solo si en el futuro se migra el
canal de WhatsApp a la Cloud API oficial de Meta (HTTP puro, sin
Chromium) — recién ahí se abre la puerta a serverless reactivo.

**Consecuencia para la PC de casa:** los agentes NO compiten por RAM/CPU
con FinancePY — quedan en Railway, la PC queda libre exclusivamente para
FinancePY (Docker cap 4GB), sin el problema de contención de recursos
analizado antes.

### Rendimiento — Railway vs PC local vs VM GCP actual

| Factor | Railway | PC local | VM GCP (actual) |
|---|---|---|---|
| Uptime | Alto (infra gestionada) | Depende de luz/internet de casa | Alto |
| Latencia a Paraguay | Buena si región US/EU cercana; sin control fino de región | Local (buena si clientes son locales) | Mala (Iowa, ~200ms) |
| Escala bajo carga | Automática (vertical/horizontal según plan) | Fija (hardware de la PC) | Fija (tamaño de instancia) |
| Dependencia de red doméstica | No | Sí (punto único de falla) | No |
| Chromium/openwa estable | Sí (contenedor dedicado) | Sí pero compite con uso normal | Sí (ya probado) |

Railway resuelve el problema de raíz (dependencia de la PC/red doméstica)
sin la latencia geográfica de la VM actual en Iowa — mejor punto medio
para un agente de cara a clientes reales.

### Costos — estimado Railway

Railway cobra por uso real (RAM-hora + vCPU-hora), no por servidor fijo
reservado. Estimado para el footprint de este stack:

| Servicio | RAM aprox | vCPU aprox |
|---|---|---|
| openwa-api (Chromium headless) | 1-2 GB | 0.5-1 |
| n8n | 0.5-1 GB | 0.25-0.5 |
| alejandro-agent (Node, llamadas a Claude Haiku) | 0.25-0.5 GB | 0.1-0.25 |
| **Total continuo (always-on)** | ~2-3.5 GB | ~1-1.75 |

Estimado de gasto mensual: **$10-25 USD/mes** corriendo 24/7, dependiendo
de picos de uso y si se suma Postgres/Redis administrados de Railway
(cada uno agrega unos $5-10/mes según tamaño).

⚠️ **Verificar precio real en railway.app/pricing antes de comprometer** —
Railway ajusta tarifas por GB-hora/vCPU-hora periódicamente, esto es
estimado de orden de magnitud, no cotización oficial.

Comparado con la VM GCP actual (e2-standard-4 compartida entre varios
servicios, costo no desglosado por servicio individual): Railway como
servicio dedicado solo para agentes probablemente sale más barato que la
porción proporcional de la VM, además de resolver la latencia.

### Costo extra — instancia fallback de FinancePY en Railway

Sumar una segunda instancia (FinancePY) en modo standby agrega costo:

| Escenario | RAM aprox | Costo aprox |
|---|---|---|
| Instancia dormida/escalada a 0 (Railway permite sleep en apps sin tráfico) | mínimo | ~$0-2/mes |
| Instancia activa 24/7 como hot-standby | 1-2 GB | ~$5-10/mes adicionales |

Recomendado: dejarla en modo dormido (Railway la despierta ante request,
o se activa manualmente restaurando el último backup de Drive) en vez de
correrla 24/7 — el costo de guardia baja a casi cero mientras la PC es
la primaria funcionando normal.

**Estimado total Railway (agentes + fallback dormido de FinancePY):
~$10-27 USD/mes** — a confirmar con calculadora oficial.

### Sleep/wake en agentes — matiz técnico por componente

No todos los componentes del stack de agentes pueden dormir igual:

| Componente | ¿Puede dormir? | Por qué |
|---|---|---|
| n8n | Sí | Webhook-triggered, Railway lo despierta al recibir request |
| alejandro-agent | Sí | Stateless, responde a webhook entrante |
| openwa-api | **No** | Mantiene conexión persistente (WebSocket vía Chromium) que simula WhatsApp Web. Si duerme, la sesión se corta |

**Por qué openwa-api no puede dormir:** WhatsApp no entrega mensajes vía
webhook HTTP — los entrega por un socket persistente que el cliente
(openwa) debe mantener abierto. No existe "mensaje entrante que despierte
el contenedor", porque **recibir el mensaje requiere que la sesión ya
esté conectada** — es la causa, no la consecuencia. Si el contenedor
duerme: la sesión se desconecta, los mensajes que lleguen mientras tanto
se pierden (no quedan en cola), y la reconexión no siempre es automática
(a veces exige reescanear QR).

Cron para tareas programadas de n8n sí funciona con sleep — Railway
soporta cron jobs sin necesitar el contenedor despierto permanentemente
para eso específicamente.

**Ahorro real:** parcial, no total del stack — n8n y alejandro-agent
bajan a modo sleep, openwa-api se mantiene always-on (es el componente
más pesado del combo, ~1-2GB, así que el ahorro de dormir los otros dos
es limitado en términos de RAM pero sí reduce vCPU-hora facturada).

## ¿Se puede usar Google Cloud (Cloud Run) en vez de Railway para los agentes?

Evaluado con precios oficiales confirmados en [cloud.google.com/run/pricing](https://cloud.google.com/run/pricing)
(Iowa/us-central1, tarifa default sin CUD): **CPU $0.000018/vCPU-segundo,
memoria $0.000002/GiB-segundo** en modo instance-based billing (always-on).

Cloud Run tiene dos modelos de cobro:
- **Request-based** (default): solo cobra mientras hay requests activos —
  ideal para tráfico intermitente, pero **no aplica a openwa-api**, que
  necesita la sesión de Chromium viva 24/7 aunque no haya requests entrando
- **Instance-based** (`min-instances` + always-allocated CPU): cobra el
  ciclo de vida completo del contenedor, corriendo o no — esto es lo que
  realmente necesitaríamos para mantener viva la sesión de WhatsApp

**Costo real de openwa-api solo (1 vCPU + 2GB, 24/7, instance-based):**

| Recurso | Cálculo | Costo/mes |
|---|---|---|
| CPU | 2,592,000 seg × $0.000018 | ~$46.66 |
| RAM | 2 GiB × 2,592,000 seg × $0.000002 | ~$10.37 |
| **Total solo openwa-api** | | **~$57/mes** |

Eso ya solo, **supera el estimado de Railway para el stack completo**
(~$10-27/mes con n8n + alejandro-agent + openwa-api + fallback FinancePY).
n8n y alejandro-agent podrían quedar en modo request-based (más barato,
similar a Railway sleep), pero openwa-api en instance-based ya domina el
costo total.

**Por qué pasa esto:** Cloud Run está optimizado para escalar a cero y
cobrar solo ráfagas de tráfico — el "always-on" es la excepción cara, no el
caso de uso principal. Railway, en cambio, está pensado desde el vamos para
correr contenedores continuos (como una VM chica gestionada), por eso su
tarifa por hora continua es más competitiva para este patrón.

Aparte del costo, operativamente Cloud Run tampoco es el mejor fit: sus
instancias pueden reciclarse por mantenimiento de la plataforma incluso con
`min-instances`, algo que rompería la sesión de WhatsApp de forma similar al
problema de "sleep" ya descartado — Railway da más garantía de "este
contenedor corre ininterrumpido" para este patrón específico.

**Conclusión: Railway sigue siendo la opción, Cloud Run sale más caro y
menos apto para el componente que más importa (openwa-api).**

## Networking: exponer sin abrir puertos

- **Cloudflare Tunnel** (gratis) en vez de port-forwarding en el router
- Resuelve el problema de IP dinámica sin necesitar DDNS
- No expone puertos directos a internet — reduce superficie de ataque
- Certificado TLS gestionado por Cloudflare
- Config real lista: [`docs/cloudflared-config.yml.example`](../../docs/cloudflared-config.yml.example)
  en el repo `financespy` — pasos de setup completos en el comentario del archivo

## Backups — corregido: no hace falta pg_dump para FinancePY

**Confirmado leyendo `compose.prod.yml` y `.env.production.example` reales:**
la base de datos de FinancePY vive en **Supabase** (Postgres gestionado,
proyecto "CD Finanzas"), no en un contenedor local. El plan original de
`pg_dump` + Drive asumía un Postgres local que nunca existió — Supabase ya
gestiona sus propios backups automáticos (point-in-time recovery según plan
contratado). **No hay nada que respaldar manualmente para la DB de FinancePY.**

Lo único potencialmente local es el volumen `app-storage` (ActiveStorage —
adjuntos subidos por usuarios, si los hay). Si se usa poco/nada, no amerita
backup automatizado; si se usa activamente, considerar más adelante subir
adjuntos a Supabase Storage en vez de volumen local (saca el problema de raíz).

Para la VM GCP: ya existe backup real e independiente — `alejandro-daily-backup`,
resource policy de snapshot diario del disco, confirmado en
`gcloud compute disks describe alejandro-vm`. Cubre n8n/alejandro-agent/
openwa-api mientras sigan ahí; una vez migrados a Railway, ese snapshot
diario deja de ser necesario para esos componentes.

## Acceso remoto desde Mac

Con solo FinancePY corriendo en la PC (agentes en Railway), el margen de
RAM libre es amplio (~10-12GB de 16GB) — no afecta el uso normal.

Opciones de conexión remota Mac → PC:

1. **RDP (Escritorio remoto de Windows)** — gratis, nativo en Windows 10
   Pro. App "Microsoft Remote Desktop" en Mac App Store. Control total
   del escritorio.
2. **SSH a WSL2** — gestión de Docker por terminal (`docker logs`,
   `docker compose restart`, etc.) sin abrir el escritorio completo.
3. **Portainer** (opcional) — UI web para administrar contenedores desde
   el navegador, sin RDP ni SSH.

⚠️ No exponer RDP directo a internet (puerto 3389 abierto = blanco de
ataques de fuerza bruta). Usar **Tailscale** (VPN mesh gratis) instalado
en Mac y PC — conecta como si estuvieran en la misma red local, sin abrir
puertos en el router. Alternativa: sumar una ruta al mismo Cloudflare
Tunnel ya planeado para la app.

## Checklist de implementación

- [ ] Activar WSL2 en Windows (`wsl --install`) + Docker Desktop
- [x] `compose.local.yml` + `Caddyfile.local` con límites de memoria/CPU — ya en el repo `financespy`
- [ ] Copiar el repo a la PC, `cp .env.production.example .env.local` y completar valores reales
- [ ] `docker compose -f compose.local.yml --env-file .env.local up -d --build`
- [ ] Cloudflare Tunnel: seguir pasos en `docs/cloudflared-config.yml.example`
- [ ] Migrar todo lo necesario fuera de la VM GCP (n8n/agentes a Railway, FinancePY a PC), luego desactivarla/eliminarla por completo
- [ ] Migrar n8n + alejandro-agent + openwa-api a Railway
- [ ] Crear instancia fallback de FinancePY en Railway (modo dormido/escalada a 0), apuntando a restaurar backup de Drive ante caída de la PC
- [ ] Instalar Tailscale en Mac y PC para acceso remoto seguro
- [ ] Configurar RDP en la PC (Windows 10 Pro ya lo soporta nativo)
- [ ] Avisar a testers que es entorno beta, sin SLA garantizado
- [ ] Definir criterio de "listo para comercializar" → dispara migración a São Paulo

## Riesgo asumido conscientemente

Cortes de luz/internet en la casa tumban el sistema para los testers durante
la fase de prueba. Aceptable dado que no es comercial todavía — pero debe
comunicarse explícitamente a quienes prueben el sistema.

## 2026-08-04 — Corrección: la PC real es otra (notebook, no HP EliteDesk)

**La máquina que se va a usar es distinta a la de este documento.** Specs
confirmadas por el usuario: **notebook Windows, i5 7ma generación, 8GB RAM,
832GB de almacenamiento libre** — no el HP EliteDesk 705 G4 SFF (Ryzen 3
PRO 2200G, 16GB) descrito arriba. El EliteDesk pudo haber sido reemplazado
o nunca fue la máquina definitiva; no se investigó cuál es cuál, solo se
confirmaron los specs de la que se va a usar.

**Impacto en el plan de recursos — corregido 2026-08-05 con medición real:**
el cap de `compose.local.yml` (~2.7GB tras el sync del 04/08) es un **techo
de seguridad, no consumo esperado**. Medido con `docker stats` en la VM de
producción sirviendo tráfico real:

| Container | RAM real |
|---|---|
| web (Rails/Puma) | 372 MiB |
| worker (Sidekiq) | 344 MiB |
| caddy | 24 MiB |
| redis | 5 MiB |
| **Total** | **~745 MiB** |

Cuentas reales para la notebook de 8GB: Windows (~2-2.5GB) + WSL2/Docker
Desktop (~1-1.5GB) + FinancePY (~0.75-1GB) = **~4-5GB, dejando 3-4GB
libres**. Margen cómodo, no ajustado.

**Corrección explícita:** una versión anterior de esta sección estimaba
"~1-2GB de margen" calculando sobre el techo de 3.1GB en vez del consumo
real — era pesimista por ~4x. La notebook **no necesita quedar dedicada**
al servidor; uso diario normal en paralelo es viable.

Dos riesgos reales que sí quedan en pie:
1. **El build de la imagen Docker** (`bundle install` + `assets:precompile`)
   pega un pico de memoria muy superior al de operación normal — es el
   momento de mayor riesgo de OOM, no el día a día.
2. Sumar los agentes a la misma máquina (openwa con Chromium headless,
   ~1-2GB) sí volvería todo ajustado — pero ya está decidido que van a
   Railway, así que no aplica salvo que se revierta esa decisión.

Guía de ejecución paso a paso (con esta notebook, considerando el problema
de control remoto por AnyDesk): [[FinancePY — Guía paso a paso migración VM a notebook Windows]].

## 2026-08-05 — Alternativa multi-dispositivo (Tailscale) evaluada y no adoptada; proyecto en pausa

Se exploró una variante más ambiciosa: correr FinancePY en cualquiera de
varios dispositivos propios (no solo la notebook), sin VM, con acceso
entre dispositivos vía red aunque estén en redes distintas (casa/oficina/
datos móviles). Aclarado en la conversación:

- **DB sigue en Supabase** en cualquier escenario — no se evaluó tener
  Postgres local por dispositivo con sync real (correctamente descartado:
  motor de sync + resolución de conflictos es proyecto grande y riesgoso
  para datos financieros).
- Patrón de uso real: **un solo dispositivo corre el server a la vez**
  (no instancias concurrentes en paralelo) — los demás acceden como
  clientes remotos.
- Transporte propuesto: **Tailscale** (mismo mecanismo ya listado arriba
  en "Acceso remoto desde Mac", sección de networking) en vez de
  Cloudflare Tunnel — malla privada, sin exponer nada públicamente, buen
  fit dado el historial de hardening de seguridad de este proyecto.

**No se adoptó formalmente** — el usuario pausó el proyecto antes de
aprobar el diseño. La decisión vigente sigue siendo la de este documento
(notebook Windows fija + Cloudflare Tunnel, plan ya preparado y con guía
lista). Si se retoma, decidir explícitamente Cloudflare Tunnel (ya
preparado) vs. variante Tailscale/multi-dispositivo antes de tocar código
— no asumir que se sigue con lo ya armado sin confirmar.

**Estado del proyecto: pausado (2026-08-05).**

## 2026-08-07/08 — Retomado y ejecutado: migración real en producción

Contradice la nota de pausa de arriba — el usuario retomó y ejecutó, sin
reabrir la variante Tailscale: se siguió con Cloudflare Tunnel, ya
preparado, como decía el plan vigente.

**Estado real ahora: `finance.cd-co.com.py` corriendo en la notebook, en
producción, VM GCP apagada.** No es un ensayo — hubo un corte de luz real
durante la migración (~50 min de downtime, recuperado a mano) y varias
rondas de fixes reales sobre el Caddy de producción. Detalle completo,
incluyendo el hallazgo de que WSL2 no arranca solo al boot (pendiente:
[[FinancePY — Arranque automatico y fallback (notebook WSL2)]]) y la saga
del `Cache-Control` del service worker (PRs #66/#68/#69), en
[[Migración hosting FinancePY — análisis Cloudflare vs alternativas]] y
en `wiki/log.md` (entrada 2026-08-07/08).

Aparte, se generó un APK Android real (TWA vía Bubblewrap) de la PWA —
funciona por sideload, sin necesitar cuenta de Play Console. Ver nota
[[FinancePY — APK Android (TWA) con Bubblewrap]].
