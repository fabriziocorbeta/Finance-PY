---
type: meta
title: "Reporte de Modificaciones — FinancePY 2026-07-23"
created: 2026-07-23
tags: [meta, reporte, financespy, agente-ia-cdco]
---

# Reporte de Modificaciones — 2026-07-23

Todo deployado y verificado en producción salvo lo marcado como pendiente. Ver [[Sesión 2026-07-22-23 FinancePY ventas + seguridad + migración]] para el relato completo de la sesión.

## FinancePY (repo `cd-co-erp`, rama `main`)

| Commit | Cambio | Estado |
|---|---|---|
| `688e6b8` | Nota de venta + nota de entrega (PDF/print), campos nuevos en Sale | ✅ deployado |
| `05b9e11` | Fix CSP: `onclick` inline → Stimulus (`row_click_controller.js`) en 4 vistas | ✅ deployado |
| `7fb8fb2` | Nota de entrega usa `brand_name` (no `Current.family.name`), agrega `delivery_address`/`delivery_date` | ✅ deployado |
| `ea1322f` | Label "Fecha de envío" en vez de "Fecha de entrega" | ✅ deployado |
| `50517dc` | Campo `carrier` (transportadora) en Sale + formulario + nota de entrega | ✅ deployado |
| `325d5ca` | Rediseño nota de venta/remito estilo Shopify (solo formato, sin alterar datos) | ✅ deployado |
| `41cefe4` | Elimina sección de firmas del remito | ✅ deployado |
| `c77ff46` | `compose.local.yml`: límites bajados a ~3.1GB RAM / ~1.6 cores | ✅ en repo, sin deployar (host aún no migrado) |
| `36f1d56` | Agrega `Caddyfile.local` + `docs/cloudflared-config.yml.example` (faltaban del commit anterior) | ✅ en repo |
| `0fe8eb5` | Directiva "detailed thinking off" en el prompt del asistente | ✅ deployado |

**Migraciones DB aplicadas en prod:** `20260722030000` (`delivery_address`, `delivery_date`), `20260722040000` (`carrier`).

### PWA offline-first — Ventas (spec → plan → implementación, 6 tareas)

Spec: [[FinancePY - PWA offline-first design]] · Plan: `docs/superpowers/plans/2026-07-23-financespy-pwa-offline.md`. Opción A: cache de lectura runtime (todo lo visitado queda disponible offline) + cola de escritura IndexedDB solo para creación de Ventas, single-device.

| Commit | Cambio | Estado |
|---|---|---|
| Task 1 | JSON format en `SalesController#create` | ✅ deployado |
| `b9c9489` (Task 2) | `offline_sales_db.js` — helper IndexedDB (`pending_sales` store) | ✅ deployado |
| `ad395df` (Task 3) | `offline_sale_form_controller.js` — intercepta submit sin conexión, encola | ✅ deployado |
| `da0ee8b` (Task 4) | `pending_sales_controller.js` — UI de ventas pendientes + reintento manual | ✅ deployado |
| `f724f54` (Task 5) | `service-worker.js` — cache runtime network-first + Background Sync (`sale-sync`) | ✅ deployado |
| Task 6 | Deploy y verificación en VM | ✅ verificado |

### Splash/loading screen Android + iOS

| Commit | Cambio | Estado |
|---|---|---|
| `18c02cf` | Fix icono maskable (safe-zone 40%, antes se veía como cuadrado negro clipeado en Android), `CACHE_VERSION` → `v4`, optimización de percepción de carga en ambas plataformas | ✅ deployado |

### Auditoría total FinancePY (bugs + seguridad, 2026-07-23)

Plan: `docs/superpowers/specs/2026-07-23-financespy-full-audit-plan.md`. Ejecutada bajo presupuesto de 9 min con subagentes especializados (Fases 1, 2, 4, 5 — Fase 3 OWASP completa quedó afuera, ver pendientes).

| Fase | Resultado |
|---|---|
| Fase 1 (superficie nueva: SalesController, cola offline, migraciones, modelo IA, manifest/SW) | ✅ limpia, sin hallazgos |
| Fase 2 (re-confirmación baseline: CORS, CSP, rate-limit, onboarding, Brakeman) | ✅ confirmado, conteo de Brakeman estable (falsa alarma inicial corregida) |
| Fase 4 (bundler-audit) | ⚠️ bloqueado — `bundle-audit update` no puede clonar el advisory-db (git/red restringida en el contenedor) |
| Fase 5 (bugs/correctness) | 5 hallazgos → 2 resueltos ahora, 3 pendientes (ver abajo) |

**Hallazgos Fase 5 y resolución (commit `9f78a23`):**

| # | Hallazgo | Estado |
|---|---|---|
| 1 | N+1 en `SalesController#set_sale` (afecta show/print/delivery_note) | ✅ fix: `.includes(sale_items: :product)`, deployado |
| 2 | Sin idempotencia en cola offline de Ventas → duplicados si el service worker reintenta tras POST exitoso interrumpido | ✅ fix: `client_request_id` (UUID cliente) + dedup vía `Rails.cache` en `SalesController#create` (24h TTL, sin migración) |
| 3 | `replayPendingSales()` sin guard de reentrancia — `sync` y `message` podían dispararse en paralelo y duplicar el POST | ✅ fix: lock `replayInFlight` |
| 4 | Botón de reintento manual sin protección contra doble-click | ✅ fix: se deshabilita al primer click |
| 5 | `delivery_date` sin validación de rango (acepta fechas pasadas) | ⏳ pendiente, baja prioridad |

Verificación: `ruby -c` + `node --check` en los 4 archivos tocados, deploy real en `alejandro-vm`, confirmado `HTTP 302` (redirect a login, sitio sano) post-deploy.

## Infraestructura (VM `alejandro-vm`, GCP)

| Cambio | Detalle | Estado |
|---|---|---|
| Disco redimensionado | 30GB → 50GB (`gcloud compute disks resize` + `growpart`/`resize2fs` en caliente) | ✅ aplicado, resuelve fallos recurrentes de build por espacio |
| `OPENAI_MODEL` | `meta/llama-3.1-8b-instruct` → `nvidia/nemotron-3-nano-30b-a3b` | ✅ aplicado y verificado con mensaje real en prod |
| Firewall (pendiente de revisar) | `openwa-qr-temp`/`openwa-qr-temp2` (puerto 2785 público, sin uso real — el puerto solo escucha en 127.0.0.1) y `default-allow-rdp` (puerto 3389, sin servicio RDP en este Linux) — reglas vestigiales, sin riesgo activo hoy pero recomendable eliminarlas | ⚠️ identificado, no eliminado aún |
| `alejandro-agent`/`n8n`/`openwa-api` parados | `docker stop` (restart policy `unless-stopped`, no vuelven solos). No respondían mensajes — causa real en otra capa (sesión WhatsApp/n8n), el container corría sano igual. Código intacto en repo, migración a Railway pendiente | ✅ aplicado, reduce consumo mientras no se usan |
| VM resizeada 2 veces | `e2-standard-4` (4vCPU/16GB) → `e2-standard-2` → `e2-medium` (2vCPU/4GB). Downtime real ~3-5 min cada vez (aceptado). Solo FinancePY corre hoy en la VM | ✅ aplicado, verificado con `curl` (`HTTP 302`) post cada resize |
| Costo estimado (list price, sin billing API) | Antes ~$98/mes solo compute (e2-standard-4). Ahora ~$25-30/mes total (compute e2-medium + disco + egress) | ✅ reducido ~70% |

## alejandro-agent (repo `AI-Agent1-Alejandro-CD-Co`, rama `feat/n8n-router`)

| Commit | Cambio | Estado |
|---|---|---|
| `8a6f046` (main) → `e935c37` (merge a feat/n8n-router) | **Fix de seguridad crítico**: `/webhook` y `/health/reconnect` sin auth, expuestos a todo internet — ahora verifican HMAC (`X-OpenWA-Signature`) y secreto estático respectivamente | ✅ deployado y verificado con curl real (403 sin firma, 200 con firma correcta) |
| — | `npm audit fix`: 4/6 vulnerabilidades de dependencias resueltas sin breaking changes | ✅ aplicado |
| Config VM | `OPENWA_WEBHOOK_SECRET` agregado a `/home/Fabrizio/.env` + `start-gcp.sh`; webhook de openwa-api actualizado con `secret` vía API | ✅ aplicado |

## CLS real resuelto + auditoría externa verificada (2026-07-24/25, commits `b5c8c25`..`d4e120e`)

### CLS de la pantalla de login: 0.231 → 0-0.006 (Lighthouse score 84→97-99)

Los primeros 2 intentos de fix (dimensiones HTML en el logo, luego fallback de fuente con métricas reales de Geist calculadas vía `fontTools`) **no movieron el número** — verificado con 3-4 corridas de Lighthouse cada vez, no asumido. Causa real encontrada con un probe de Puppeteer + `PerformanceObserver` (rects reales, no el resumen heurístico de Lighthouse que atribuía mal la causa al logo):

- **Root cause real**: `viewport_controller.js` fijaba `--app-height` (reemplaza el fallback `100dvh`) recién en `connect()` de Stimulus, después del primer paint. Cuando `window.innerHeight` difería del valor `100dvh`, toda la pantalla centrada verticalmente saltaba de una.
- **Fix**: mismo cálculo pero inline y síncrono en `<head>`, después de `<meta viewport>`. El primer intento lo puso ANTES del viewport meta → `window.innerHeight` leía el default de escritorio → empeoró todo a CLS 0.577 (detectado con las 3 corridas de control y corregido en la misma sesión).
- **Bonus**: `_dark_mode_check.html.erb`/`_privacy_mode_check.html.erb` sin nonce CSP, bloqueados silenciosamente desde que CSP enforce se activó (18/07) — dark mode y privacy mode nunca funcionaron en prod hasta este fix.
- Otras optimizaciones de la misma ronda: Caddy `gzip`→`zstd gzip`, `Cache-Control: immutable` 1 año en `/assets/*`, `width`/`height` HTML explícitos en logos estáticos.

### Auditoría externa sobre `cd-co-erp` — verificada contra código real, 6/6 claims confirmadas

| # | Hallazgo | Verificación | Fix |
|---|---|---|---|
| 1 | Repo público + LICENSE AGPL-3.0 + README diciendo "no es open-source" (producto propio) | Confirmado: `gh repo view` mostraba `PUBLIC`, LICENSE real, README línea 59 explícita | **Repo puesto en privado** (decisión del usuario). Grep de todo `git log --all -p` por patrones de credenciales — limpio |
| 2 | CI roto en `main` | Confirmado con `gh run view --log-failed`: Biome en `pending_sales_controller.js:72` (regresión propia del mismo día) + Mocha stub faltante para `:github` en `SettingsTest#can_update_self_hosting_settings` | Ambos arreglados, CI verde confirmado con `gh run watch` |
| 3 | **PDF de extracto no se lee** (reclamo real del usuario) | Confirmado: `Provider::Openai::PdfProcessor#process_with_vision` llama `system("pdftoppm", ...)` para PDFs escaneados, pero el Dockerfile nunca instaló `poppler-utils` — grep vacío | Agregado el paquete, verificado `which pdftoppm` en el container deployado |
| 4 | Defaults inseguros en `compose.prod.yml` (`ONBOARDING_STATE:-open`, `CSP_REPORT_ONLY:-true`) | Confirmado en el archivo; la VM ya tenía `.env` con los valores correctos | Cambiados a `closed`/`false` — solo red de seguridad para un deploy futuro incompleto |
| 5 | `config.hosts` sin usar (boilerplate Rails nunca activado) | Confirmado, comentado desde siempre | Activado a `["finance.cd-co.com.py"]` + exclude `/up` para healthcheck |
| 6 | `redis:latest` sin pin, Postgres/Redis sin tag en CI | Confirmado | Pineado a `redis:8.8` (matchea versión real en prod) y `postgres:17` en CI (matchea gem `pg` 1.5.9) |

**No hecho esta ronda (deferido explícitamente):** unificar el flujo dual `StatementImport`/`PdfImport` de importación de extractos, fixtures de regresión de PDF (texto, escaneado, corrupto, protegido) — tarea de varios días, no un fix de config.

## Import de PDF de extractos — 4 bugs reales, 3 resueltos (2026-07-25/27)

El usuario reportó "no me lee el PDF de mi TC" con un extracto real (AMEX Gold, Itaú, 4 páginas, texto extraíble, ~35 transacciones). Se rastreó y resolvió una cadena de 3 bugs reales, uno detrás de otro — cada fix destapaba el siguiente:

| # | Bug real | Cómo se confirmó | Fix | Commit |
|---|---|---|---|---|
| 1 | Form no se enviaba nunca | CSP bloquea `onchange="this.form.submit()"` inline — nonces no cubren atributos de evento, solo `<script>`. Confirmado con consola del navegador: "Refused to execute a script for an inline event handler" | Stimulus `auto_submit_controller.js`. De paso: 5 casos más del mismo patrón arreglados (doorkeeper confirm → `data-turbo-confirm`, reload button, 2× `stopPropagation` en snaptrade/indexa) | `69db2c8` |
| 2 | Fallback OCR roto | `poppler-utils` nunca instalado en Dockerfile, `pdftoppm` fallaba silencioso — no afectó este PDF (tenía texto real) pero confirmado real vía grep | 1 paquete apt agregado | `d4e120e` |
| 3 | **Causa real de "no me lee el PDF"** | El modelo (Nemotron nano vía NVIDIA) a veces devuelve JSON válido con la PRIMERA clave corrupta: `{".document_type": "credit_card_statement", ...}` — `parsed["document_type"]` no matchea, cae silencioso a "other". Reproducido con el PDF real, capturado el raw response exacto | `normalize_keys`: strip de caracteres no alfanuméricos al inicio de cada clave, en el único punto de parseo compartido por texto+visión | `445939d` |
| 4 | **Sin resolver**: extracción de transacciones vacía | Con clasificación ya correcta (metadata perfecta: banco, titular, tarjeta), `BankStatementExtractor` devuelve `transactions: []` consistente. Confirmado que NO es parseo — a veces basura (`{">>>start_jsonspiel>>>": "<START>"}`), a veces JSON válido con array vacío. 3 capas de retry agregadas (vacío/basura, timeout de red, array vacío específico) — ninguna resolvió el fondo | Probado modelo más grande (`nemotron-3.3-super-49b-v1.5`): timeout en las 3 pasadas (2 min c/u), muy lento para el cliente HTTP actual | `3ac7ffa`, `389c48c`, `9824733` (mitigaciones, no fix) |

**Diagnóstico real del bug #4:** limitación de capacidad del modelo nano para esta tarea específica de extracción estructurada de listas largas, no un bug de código. Decisión pendiente: modelo más grande + subir timeout del cliente (viable en job async de background, este import corre en Sidekiq no en request-response) vs. rediseñar prompt/chunking para que el nano lo maneje mejor.

**Bugs menores encontrados en el camino, no resueltos (fuera de scope de esta ronda):**
- SMTP no configurado en la VM — `PdfImportMailer#next_steps` falla siempre (`Connection refused... port 25`), reintenta sin parar en la cola `high_priority`. No bloquea el import pero es ruido real y una feature rota (el usuario nunca recibe el aviso).
- Vector Store 404 confirmado otra vez (`POST /v1/vector_stores` no existe en NVIDIA NIM) — capturado como warning no-fatal, no bloquea. Toda la feature de búsqueda de documentos vía `VectorStore::Openai` es código muerto con NVIDIA como proveedor.

**Import de prueba real que quedó en la DB, no borrado:** `PdfImport` `14a95333-d1eb-4e02-b3d9-3c4166a703ce` — usado para reproducir sin re-subir el PDF. `rows_count: 0`, metadata correcta.

## Decisiones tomadas

1. **Hosting definitivo**: FinancePY → PC local (Docker + Cloudflare Tunnel), agentes → Railway, VM GCP se desactiva por completo. Ver [[FinancePY - Hosting fase prueba (PC local)]]. **Migración pospuesta a mañana por decisión del usuario** — riesgo marcado: el crédito GCP Free Credit vencía el mismo día 23/07 (confirmado en billing real), "mañana" cae después del vencimiento.
2. **Modelo IA del asistente**: se mantiene `nemotron-3-nano-30b-a3b` pese a latencia real de 15-31s bajo tool-calling completo (vs 2.8-4.8s en test aislado simple) — decisión explícita de priorizar corrección sobre velocidad en app financiera. Ningún modelo probado (12+, barrida completa Nemotron/Llama/DeepSeek/Gemma/MiniMax/GLM/Mistral/Qwen) es simultáneamente rápido y correcto bajo carga real.
3. **Memoria del asistente estilo Nous Research/Hermes**: identificado como feature nueva (RAG/vector store, no existe hoy) — brainstorm no iniciado aún.

## Pendiente / próximos pasos

- [ ] Ejecutar migración FinancePY → PC local (prompt completo preparado para sesión nueva de Claude Code en Windows) — pospuesta, verificar estado real del crédito GCP (vencía 2026-07-22/23)
- [ ] Eliminar firewall rules vestigiales (`openwa-qr-temp`, `openwa-qr-temp2`, `default-allow-rdp`) en GCP
- [x] ~~Brainstorm PWA offline-first~~ → implementado y deployado completo (ver arriba)
- [ ] Fase 3 del audit (OWASP completo, sistema entero) — deferida, la más cara en tiempo
- [ ] Fase 4 del audit (bundler-audit) — bloqueado, requiere resolver acceso git/red del contenedor a `rubysec/ruby-advisory-db`
- [ ] Validación de rango en `Sale#delivery_date` (hallazgo #5 Fase 5, baja prioridad)
- [ ] Brainstorm memoria persistente del asistente (estilo Hermes/Nous Research) — no iniciado
- [ ] Evaluar streaming (`streamer:` param ya existe en `chat_response`) para mejorar percepción de velocidad del asistente sin sacrificar corrección
- [ ] Revisar `/shopify/orders-webhook` (sin HMAC) y `/shopify/inventory-webhook` (fail-open si falta secret) en alejandro-agent — severidad baja, no resuelto esta sesión
- [ ] Unificar flujo dual `StatementImport`/`PdfImport` de importación de extractos + fixtures de regresión de PDF — identificado 2026-07-25, no iniciado
- [ ] Borrar LICENSE (AGPL) del repo ahora que es privado — cosmético, ya no tiene efecto legal pero genera confusión
- [ ] Eliminar `alejandro-agent`/`n8n`/`openwa-api` del disco de la VM una vez migrados a Railway (hoy solo están parados, no borrados)
