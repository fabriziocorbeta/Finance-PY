---
type: session
title: "Sesión 2026-07-16 FinancePY security fixes deploy"
created: 2026-07-16
updated: 2026-07-18
tags:
  - financespy
  - seguridad
  - deploy
  - performance
  - sesion
status: resolved
related:
  - "[[financespy]]"
  - "[[FinancePY — Auditoría de seguridad y code smells (75 hallazgos)]]"
  - "[[Naming FinancePY]]"
  - "[[Migración hosting FinancePY — análisis Cloudflare vs alternativas]]"
---

# Sesión 2026-07-16 — FinancePY security fixes P0/P1 (verificación + deploy)

Ejecución del handoff de la auditoría de seguridad: verificar cada P0/P1 contra el código real, armar PR, mergear y deployar a prod `finance.cd-co.com.py` (VM `alejandro-vm`). El reporte auto-generado estaba inflado como se advertía — de 5 P0 solo 3 accionables.

## Triage verificado (branch `main`, repo `cd-co-erp`)

| Hallazgo | Veredicto | Acción |
|----------|-----------|--------|
| CORS `*` (`cors.rb:13`) | ✅ real | allowlist `finance.cd-co.com.py` vía env `CORS_ALLOWED_ORIGINS`. Móviles nativos no mandan `Origin` → sin impacto Flutter |
| Rate-limit login | 🟡 parcial | rack-attack ya cubría oauth/token, admin, MFA, api. Faltaba login web/API → throttles `POST /sessions` + `POST /api/v1/auth/login` (10/min/IP) |
| CSP comentada | ✅ real | activada **report-only** + nonce + posthog. Enforce vía `CSP_REPORT_ONLY=false` (pendiente) |
| XSS `changelog.html.erb:24` | ✅ real | `sanitize()` en vez de `html_safe` |
| XSS `guides/show.html.erb:4` | ✅ real | `sanitize()` en vez de `html_safe` |
| `confirm_dialog` innerHTML | 🟢 bajo | `textContent` (a pedido) |
| Admin guard sin `return` (`base_controller.rb`) | ⚠️ **falso positivo** | Rails auto-halta la cadena `before_action` en `redirect_to`; no-admin nunca llegaba. Se agregó `and return` = claridad defensiva |
| TestController expuesto | ⚠️ **falso positivo** | rutas solo bajo `if Rails.env.test?` — no existe en prod |
| "5 controladores innerHTML" | ⚠️ **mayoría falso positivo** | de 13 usos, casi todos `= ""`, templates estáticos o respuestas server same-origin |

## PR y merge

**PR #51** `security: fix verified P0/P1 audit findings` — 1 PR agrupado, squash merge, commit `1fdcdb2`. 7 archivos.

**CI rojo pero preexistente:** los 4 checks fallidos (lint, scan_ruby, test, Vercel) son deuda técnica de `main` — verificado byte-a-byte idéntico a los PRs #49 y #50 ya mergeados (mismo archivo/línea: `sales_controller_test.rb:55` syntax error, `fuel_logs_controller.rb` mass-assignment, EOL Rails, lint en archivos nunca tocados). Ninguno de los 7 archivos del PR aparece en las anotaciones. El equipo mergea con CI rojo — patrón establecido.

## Deploy prod (VM `alejandro-vm`)

Repo en la VM: `/home/Fabrizio/financespy` (no `/path/to/...`). Flujo:
```bash
cd /home/Fabrizio/financespy
git pull origin main                                    # db1032c..1fdcdb2 fast-forward
docker compose -f compose.prod.yml build web worker     # ~205s
docker compose -f compose.prod.yml up -d web worker      # redis healthy, web+worker started
```
Puma 6.6 (Ruby 3.4.7 +YJIT) booteó OK en producción. Primer curl dio 502 (timing: disparó durante boot de ~10s); tras boot → 302.

## Verificación runtime end-to-end (curl contra prod)

- **CORS** ✅ — `Origin: https://evil.com` sobre `/api/v1/auth/login` → sin header `access-control-allow-origin`.
- **CSP** ✅ — header `content-security-policy-report-only: default-src 'self' https:; ...; script-src ... https://us.i.posthog.com 'nonce-'; ...` presente.
- **Rate-limit login** ✅ — `POST /sessions` × 11 → `422 422 422 422 422 422 422 422 422 422 429` (throttle dispara en el 11).
- Admin guard: no testeado en runtime (requiere sesión no-admin); fix cosmético sobre falso positivo.

## Pendientes / follow-ups

- **CSP enforce:** pasar `CSP_REPORT_ONLY=false` tras observar reportes de violación. Ojo: nonce sale vacío (`'nonce-'`) en requests no autenticados — revisar antes de enforce.
- **P2/P3 siguen abiertos:** SQL injection por interpolación (`auto_transfer_matchable.rb:13`), TOCTOU (`family.rb`, `auto_transfer_matchable.rb`), `DataCacheClearJob` sin WHERE, primer registro = super_admin (confirmar registro cerrado en prod), deuda técnica varia.
- ~~**CI de `main` roto**~~ **RESUELTO (2026-07-16, continuación):** PR #52 (syntax error `sales_controller_test.rb` que abortaba toda la suite + rubocop tanda 1), commit `b210ab5` (rubocop -A tanda 2 desde la VM), PR #53 (brakeman.ignore con fingerprints reales generados vía workflow temporal en CI + exclusiones pipelock para placeholders). Estado final CI: `lint` ✅ `scan_ruby` ✅ `security-scan` ✅ `lint_js` ✅ `scan_js` ✅. Sigue rojo: `test` (bugs reales destapados: `Money#round` ×6, `Provider::PlaidAdapter::Plaid` ×15 — debugging aparte) y Vercel (proyecto `cd-co-hub` JS, aparte).
- **Truco reusable:** fingerprints de brakeman no se pueden calcular a mano; se generan corriendo `bin/brakeman -f json` en un workflow temporal de GitHub Actions y extrayendo del log. Ojo en la VM: `docker compose run` sin `-v "$PWD":/rails` corre contra el código horneado en la imagen y los cambios se pierden con `--rm`.

---

# Continuación — cierre completo (2026-07-17/18)

## Test suite: de 152 a 0 fallas reales (PRs #54-58)

Con CI restaurado, la suite completa reveló 152 fallas nuevas (estaban tapadas por el syntax error que abortaba todo antes). Triage y reparación en 5 tandas:

- **PR #54** — CorsTest reescrito para semántica de allowlist (no wildcard); guards de gema opcional `plaid`/`snaptrade` ausente.
- **PR #55** (batch 2a) — `Money#round` faltante (rompía cálculo de IVA real, `lib/money/arithmetic.rb`), `DS::Button` no aceptaba confirm string plano (rompía `sales/show`), fixture de `sale_test.rb` inventada, skips de locale/gema.
- **PR #56** (batch 3) — causa raíz de la masa de fallas i18n: `config.i18n.default_locale = :es` en prod pero `families.locale` default `"en"` en schema → mismatch entre lo que evalúa el test process y lo que renderiza el request. Fix: `default_locale :en` **solo en test env**. Más: bug real de producto — índice único obsoleto (`idx_recurring_txns_on_family_merchant_amount_currency`) bloqueaba silenciosamente 2 recurring transactions del mismo merchant en cuentas distintas (migración `20260326112218` intentaba borrar índices que nunca existieron con ese nombre). Nueva migración para dropearlo. Claves i18n faltantes agregadas en `mfa/es.yml`, `settings/securities/es.yml`, `simplefin_items/es.yml` (usuarios reales veían "Translation missing" en prod).
- **PR #57** (batch 4) — bug real: `Invitation` se borraba de invitaciones vigentes en un flujo; `.last` flaky sobre PKs UUID (orden no determinístico) en varios tests; guards de iteración de locale.
- **PR #58** (batch 5) — bug real: símbolo de Guaraní (₲) — la gem `money`/rails-i18n no lo trae nativo, hacía falta override explícito. Último `.last` flaky. Test de ruta faltante.

Resultado: CI 100% verde salvo un flaky conocido (`test/system/settings_test.rb` — mock de `Provider::Registry.get_provider` con leak entre workers paralelos, confirmado 3+ veces sin relación a ningún diff — queda en backlog para estabilizar el mock).

## P2/P3 de la auditoría original — cierre (PR #59, #60)

- **PR #59:** `auto_transfer_matchable.rb` SQL interpolation → falso positivo (único caller nunca pasa input externo). TOCTOU en `family.rb`/`auto_transfer_matchable.rb` → ya mitigado con `rescue RecordNotUnique` de una sesión previa. SSL_VERIFY/OAuth 1yr token → config con defaults seguros. **README reescrito** — era 100% boilerplate del upstream sin adaptar.
  - **Casi-error propio, corregido a tiempo:** intenté "arreglar" `DataCacheClearJob` (borraba ExchangeRate/Security::Price global sin scope a family) sin chequear el test suite existente primero — el test YA documentaba ese comportamiento como intencional (self-hosted single-tenant, admin-gated). Reverteado antes de mergear al ver el test roto en CI. Lección reforzada: verificar contra tests existentes antes de asumir bug, exactamente lo que la auditoría original advertía sobre reportes auto-generados.
- **PR #60:** memory leak real en `file_upload_controller.js` (`.bind(this)` distinto en connect/disconnect, `removeEventListener` nunca matcheaba). `DestroyJob` tragaba errores sin loggear. `FamilyResetJob` (\"reset all my data\") no borraba las tablas ERP propias (`products`/`sales`/`purchase_orders`/`fleet_vehicles`) ni `goals`/`rules`/`recurring_transactions` — usuario reseteaba y seguía viendo datos viejos. `Holding::Gapfillable`/`Balance::Materializer` revisados y **deferidos** (riesgo real pero dataset actual mínimo, requieren profiling real antes de tocar código financiero crítico).

## Branch protection + supabase (financespy schema)

Branch protection activado en `main`: requiere `lint`/`scan_ruby`/`test`/`security-scan` verdes + branch actualizada. `enforce_admins: false` (mergeo con `--admin` 3 veces por el flake confirmado, documentado en cada caso). Schema `financespy` en Supabase verificado: **cero funciones custom**, sin superficie IDOR ahí (a diferencia del hallazgo crítico de CD & Co ERP).

## Branding: footer con atribución al fork (PR #61)

Footer visible en cada página decía "(community fork of Maybe Finance)" — expuesto a usuarios reales. Único lugar con la mención (grep confirmado). Eliminado.

## Bug de infraestructura real: env vars de seguridad nunca llegaban al contenedor (PR #62)

Al intentar cerrar el registro público (`ONBOARDING_STATE=closed`), seteado en `.env` de la VM sin efecto. Causa: `compose.prod.yml` usa un anchor `x-rails-env` con **whitelist explícita** de variables, no `env_file` passthrough — solo lo listado ahí cruza al contenedor. `ONBOARDING_STATE` nunca estuvo en esa lista. Y tampoco `CORS_ALLOWED_ORIGINS`/`CSP_REPORT_ONLY` del PR #51 — "funcionaban" solo porque el default hardcodeado en código coincidía por casualidad con el valor deseado. **CSP enforce nunca se hubiera podido activar** vía env var hasta este fix. Las 3 agregadas al anchor + documentadas en `.env.production.example`.

**Deploy con complicación:** disco de la VM llegó a 100% lleno (`docker builder prune -af` liberó 2.1-2.9GB dos veces en la sesión — se vuelve a llenar con cada tanda de rebuilds). `docker images` reveló que la VM corre 3 servicios más ajenos a FinancePY: `n8n` (2.42GB), `alejandro-agent` (2.34GB), `openwa-api`/WhatsApp (2.33GB) — comparten los mismos 29GB de disco. **Pendiente: agrandar el disco (`gcloud compute disks resize`) o mover a limpieza automática periódica.**

**Terminal rota (bracketed paste):** la terminal del usuario corrompía cualquier texto pegado (`00~...01~` como prefijo/sufijo literal) durante varios intercambios — se resolvió con `bind 'set enable-bracketed-paste off'` tipeado a mano (no pegado). Volvió a pasar más de una vez en la sesión; si reaparece, mismo fix.

## CSP report endpoint (PR #63)

`policy.report_uri` nunca estuvo seteado — CSP en report-only literalmente no reportaba nada a ningún lado, cero evidencia para "confirmar reportes limpios". Agregado `POST /csp_reports` (sin auth, sin CSRF) que loggea vía `Rails.logger.warn`. Deployado, `CSP_REPORT_ONLY=false` activado el mismo día con **cero ventana de tráfico real** (el usuario lo flippeó apenas deployado, no tras días de observación como se había planeado) — funciona (header confirmado `content-security-policy:` sin `-report-only`), pero vale revisar consola del browser en uso real por si algo rompe silenciosamente.

## Diagnóstico de performance — mobile más lento que desktop (2026-07-18)

Dos reportes en PDF (Kimi.ai) recibidos: "comparativo de arquitectura" (PWA/edge/CRDT, mayormente educativo/especulativo) e "índices en Supabase" (**contenido fabricado**: afirmaba "0 índices" cuando hay **380 reales**; referenciaba tablas `invoices`/`contacts` que no existen; columnas inventadas `sales.client_id`, `purchase_orders.supplier_id`, `fleet_vehicles.plate_number` — real es `plate`. La migración propuesta hubiera fallado en la primera línea). Mismo trato que la auditoría original: verificar contra código/DB real antes de tocar nada — nada de ese documento era accionable.

**Diagnóstico real, con evidencia:** medido desde afuera, `/sessions/new` tardaba ~650ms TTFB consistente. Medido con log de Rails desde ADENTRO de la VM (`docker compose logs`, sin la latencia de red de por medio): **`Completed 200 OK in 201.82ms`**. Rails/DB no es el problema (dataset real: 13 cuentas, 62 movimientos, 2 productos — trivial). La diferencia (~450ms) es **latencia geográfica pura**: VM en `us-central1` (Iowa), usuario en Paraguay (~7.300km, RTT típico 180-220ms), compuesta en mobile por redes celulares más lentas/con jitter.

**Evaluación São Paulo (`southamerica-east1`) vs quedarse en Iowa:** mismo tipo de máquina disponible (`e2-standard-4`, 4vCPU/16GB, 3 zonas activas). Asunción↔São Paulo ~1.000km (RTT 15-40ms) vs ↔Iowa ~7.300km — corte de latencia drástico. Costo estimado ~$122-132/mes vs ~$98/mes actual (GCP cobra ~15-30% más en Sudamérica) — sin confirmar en calculadora real. Más barato que Hetzner+Cloudflare evaluado antes, sin re-arquitecturar nada (mismo Docker Compose). Migración sería vía snapshot de disco + VM nueva + cutover DNS, reversible en cada paso. **Decisión NO tomada — evaluación en curso, no ejecutar sin confirmación explícita.**

**Conclusión de la sesión:** el pedido inicial de PWA/procesamiento local (Service Worker + IndexedDB + sync engine — proyecto grande, semanas de trabajo) **queda justificado por el diagnóstico real** (ningún servidor único gana la distancia física), pero se pausó el brainstorming de diseño para evaluar primero la alternativa más barata (mover región) antes de comprometerse a la complejidad de un sync engine offline-first.

## Errores propios de esta sesión (honestidad, para no repetir)
1. Casi rompo `DataCacheClearJob` por no chequear el test existente primero (revertido a tiempo, ver arriba).
2. Perdí el clon de `/tmp` una vez a mitad de sesión (sandbox reset) — tuve que rehacer edits de batch 3 de memoria; confirmar SIEMPRE `git log`/`git diff` tras cualquier gap de reconexión antes de asumir que el trabajo previo sigue ahí.
3. Confundí `-I` (HEAD) con GET real al testear compresión CSP — reporté "sin compresión" cuando sí funcionaba, corregido en el mismo turno.
4. Dí por hecho que `docker compose up -d` releía `.env` tras un cambio de valor — no siempre recrea el contenedor; hay que usar `--force-recreate` o confirmar explícitamente con `docker compose exec web env`.
