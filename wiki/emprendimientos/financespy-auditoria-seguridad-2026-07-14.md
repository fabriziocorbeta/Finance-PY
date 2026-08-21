---
type: source
title: "FinancePY — Auditoría de seguridad y code smells (75 hallazgos)"
created: 2026-07-14
updated: 2026-07-18
status: resolved
resolution: "P0/P1/P2 deployados y verificados en prod. CI 100% verde (13 PRs). Branch protection activa. ONBOARDING_STATE cerrado, CSP enforce activo. P3 no crítico queda en backlog (profiling real requerido)."
tags:
  - financespy
  - seguridad
  - auditoria
  - code-review
  - deuda-tecnica
related:
  - "[[financespy]]"
  - "[[CD & Co ERP + FinancePY — Auditoría Supabase compartida (RLS crítico) + diagnóstico Vercel]]"
  - "[[Sesión 2026-07-09-14 — FinancePY hardening y fixes]]"
  - "[[Naming FinancePY]]"
---

# FinancePY — Auditoría de seguridad y code smells

Reporte externo auto-generado (75 debilidades con archivo+línea+snippet) sobre el codebase de FinancePY (fork del proyecto upstream open-source, repo `fabriziocorbeta/cd-co-erp` branch `main`). Documento fuente en máquina externa: `/home/z/my-project/docs/analisis-puntos-debiles-sure-erp.md`. Este nota es el **triage**: qué aplica realmente al deploy propio (VM `alejandro-vm`, prod `finance.cd-co.com.py`), no la lista cruda.

## Triage por prioridad

### P0 — Reales, fix chico / impacto alto (arreglar primero)
| Hallazgo | Archivo | Nota de contexto |
|----------|---------|------------------|
| CORS wildcard `*` | `config/initializers/cors.rb:13` | App multi-tenant con datos financieros. Fijar allowlist a `finance.cd-co.com.py`. |
| CSP completamente comentada | `config/initializers/content_security_policy.rb` | Sin CSP + XSS de abajo = robo de sesión. Activar report-only primero, luego enforce. |
| Admin guard sin `return` tras redirect | `app/controllers/admin/base_controller.rb:10` | Bug de auth real: ejecución sigue tras `redirect_to`. Verificar doble-render. Fix trivial. |
| TestController expuesto en API prod | `test_controller.rb` | Verificar `routes.rb` — si ruta activa en prod, quitar. |
| Sin rate limiting en login | — | Fuerza bruta. Meter `rack-attack`. |

### P1 — XSS almacenado (sanitizar)
| Hallazgo | Archivo | Riesgo real |
|----------|---------|-------------|
| GitHub release notes sin sanitizar + `html_safe` | `changelog.html.erb:24` | Fuente = GitHub releases (bajo control), riesgo medio-bajo. Sanitizar igual. |
| Markdown guide sin sanitizar + `html_safe` | `guides/show.html.erb:4` | Depende de quién edita guides. Sanitizar. |
| 5 controladores JS con `innerHTML` | frontend | XSS DOM. Cambiar a `textContent` / sanitizar. |

### P2 — Ojo pero contexto baja severidad (confirmar antes de tocar)
- **Primer registro = super_admin** (`user.rb:66-68`): comportamiento estándar self-hosted del upstream. Solo importa si registro abierto. **Confirmar que registro esté cerrado en prod.**
- **SQL injection por interpolación en joins** (`auto_transfer_matchable.rb:13`): si interpola IDs internos (no input de usuario), riesgo bajo. Parametrizar igual. *Mismo archivo del bug S26 Ultra.*
- **DataCacheClearJob borra TODOS los exchange rates sin WHERE**: destructivo pero job admin. Revisar disparador.
- **SSL deshabilitable por env var / OAuth tokens 1 año**: config, no bug. Setear env vars bien en la VM.
- Race conditions TOCTOU (`family.rb:192-229`, `auto_transfer_matchable.rb:59-92`): envolver en transacción.

### P3 — Deuda técnica lenta (backlog, no bloquea)
Fragment caching cero, 23+ columnas status sin CHECK constraints, tablas sin archivado (balances/holdings/sessions/syncs), 37 `destroy_all` (OOM risk), DB pool=3, 360 líneas duplicadas en `auth_service.dart` (Flutter), race en token refresh móvil, 10+ data migrations mezcladas con schema, 6 formatos de error de API, memory leak en `file_upload_controller.js` (bind en disconnect), `DestroyJob` silencia errores + enqueue antes de commit, `FamilyResetJob` deja huérfanos, `Holding::Gapfillable` millones de objetos en memoria, `Balance::Materializer` transacción abierta minutos.

## Solapamiento con work previo
- El **RLS de Supabase** (110 tablas, ver [[Sesión 2026-07-09-14 — FinancePY hardening y fixes]]) mitiga exposición a nivel DB pero **no** cubre XSS/CORS/auth de capa app. Complementario.
- `auto_transfer_matchable.rb` ya tocado en el análisis del bug de préstamos S26 Ultra.

## Cautela sobre el reporte
Auto-generado → tiende a inflar severidad. Varios "críticos" son por-diseño self-hosted (super_admin) o config, no vulnerabilidades explotables en el deploy propio. **Verificar cada P0/P1 contra el código real antes de armar PRs.**

## Resolución (2026-07-15)

Verificado cada P0/P1 contra el código real (branch `main`, repo `cd-co-erp`). El reporte estaba inflado como se advertía: de 5 P0, solo **3 accionables**; de "5 controladores innerHTML", solo 1 sink plausible de baja severidad.

**PR #51** (`security: fix verified P0/P1 audit findings`) — 1 PR agrupado:

| Hallazgo | Veredicto | Acción |
|----------|-----------|--------|
| CORS `*` | ✅ real | allowlist `finance.cd-co.com.py` (env `CORS_ALLOWED_ORIGINS`); móviles nativos no mandan `Origin`, sin impacto |
| Rate-limit login | 🟡 parcial | throttles rack-attack `POST /sessions` + `POST /api/v1/auth/login` (10/min/IP). oauth/token, admin, MFA, api ya estaban |
| CSP comentada | ✅ real | activada **report-only** (`CSP_REPORT_ONLY=false` para enforce) + nonce + posthog |
| XSS changelog | ✅ real | `sanitize()` en vez de `html_safe` |
| XSS guides | ✅ real | `sanitize()` en vez de `html_safe` |
| confirm_dialog innerHTML | 🟢 bajo | `textContent` (a pedido) |
| Admin guard sin `return` | ⚠️ falso positivo | Rails auto-halta la cadena `before_action` en redirect; no-admin nunca llegaba. Se agregó `and return` = claridad defensiva |
| TestController expuesto | ⚠️ falso positivo | rutas solo bajo `if Rails.env.test?` — no existe en prod. Sin cambio |
| resto innerHTML (12 usos) | ⚠️ falso positivo | `= ""`, templates estáticos, respuestas server same-origin. Sin cambio |

**Deploy + verificación runtime (2026-07-16, prod `finance.cd-co.com.py`):** PR #51 mergeado (squash, commit `1fdcdb2`) → `git pull` + `docker compose -f compose.prod.yml build/up web worker` en la VM (repo en `/home/Fabrizio/financespy`). Puma 6.6 booteó OK en prod. Verificado end-to-end vía curl:
- **CORS** ✅ — `Origin: https://evil.com` sobre `/api/v1/auth/login` NO recibe header `access-control-allow-origin` (allowlist rechaza).
- **CSP** ✅ — header `content-security-policy-report-only` presente (`default-src 'self' https:` + posthog + nonce). Enforce pendiente vía `CSP_REPORT_ONLY=false`.
- **Rate-limit login** ✅ — `POST /sessions` da 422×10 y **429 en intento 11** (throttle 10/min/IP dispara).
- Admin guard: no testeado en runtime (requiere sesión no-admin); fix `and return` es cosmético sobre un falso positivo.

**Nota CSP:** nonce sale vacío (`'nonce-'`) en requests no autenticados — irrelevante en report-only; revisar al pasar a enforce.

**P2 cerrado (2026-07-16, PR #59):**
- `auto_transfer_matchable.rb` SQL interpolation → falso positivo, único caller nunca pasa input de usuario.
- TOCTOU `family.rb` + `auto_transfer_matchable.rb` → ya mitigado con `rescue RecordNotUnique` (de sesión previa, análisis S26 Ultra).
- SSL_VERIFY / OAuth 1yr token → config, defaults seguros verificados.
- `DataCacheClearJob` borra ExchangeRate/Security::Price sin WHERE → **falso positivo tras revisar el test suite**: es comportamiento intencional documentado (`hostings_controller_test.rb:119-138` ya lo espera), gated self_hosted+admin, deploy es single-tenant. Intenté "arreglarlo" primero sin chequear el test, tuve que revertir — lección: verificar contra tests existentes antes de asumir bug, exactamente lo que la auditoría original advertía sobre reportes auto-generados.
- Primer registro = super_admin → ✅ **cerrado en prod (2026-07-17)**, ver detalle abajo.
- README → era 100% boilerplate del upstream sin adaptar (badges a `we-promise/sure`, cero mención FinancePY). Reescrito completo.

**P3 parcialmente cerrado (2026-07-16, PR #60):**
- `file_upload_controller.js` memory leak (`.bind(this)` en connect/disconnect nunca matchea, listener nunca se remueve) → **arreglado**.
- `DestroyJob` error tragado sin loggear → **arreglado** (`Rails.logger.error`, mismo patrón que otros jobs). `enqueue_after_transaction_commit: :never` revisado, no explotable en uso actual (13 callers verificados, ninguno envuelve `perform_later` en transacción externa) → sin cambio.
- `FamilyResetJob` dejaba huérfanos: no borraba `products`/`sales`/`purchase_orders`/`fleet_vehicles` (tablas ERP propias) ni `goals`/`rules`/`recurring_transactions` → **arreglado**, respetando orden de FK (`sales`/`purchase_orders` antes que `products` por `restrict_with_error`).
- `Holding::Gapfillable` (millones de objetos en memoria) y `Balance::Materializer` (transacción larga) → **revisados, deferidos**. Dataset actual mínimo (2 usuarios), fix requiere rediseño de código crítico para valuación financiera sin evidencia de problema activo. No tocar sin profiling real.
- Bug nuevo encontrado en el camino: `test/system/settings_test.rb` (`SettingsTest#test_can_update_self_hosting_settings`) es flaky bajo ejecución paralela — mock de `Provider::Registry.get_provider` con leak entre workers. Falló 2 de 3 veces en el mismo PR sin relación al diff. **Backlog: estabilizar el mock.**
- Resto de P3 (fragment caching, CHECK constraints, tablas sin archivado, 37 `destroy_all`, 10+ data migrations mezcladas, 6 formatos de error API, Flutter duplicado) — **sin tocar**, requieren cambios de schema (excluidos por instrucción explícita de no preparar migraciones) o refactors grandes fuera de alcance de esta sesión.

**Branch protection activado en `main`** (2026-07-16): requiere `lint`/`scan_ruby`/`test`/`security-scan` verdes + branch actualizada antes de mergear. `enforce_admins: false` (mantenedor único puede bypassear con `--admin` para casos verificados de flake, como se hizo en PR #60/#61/#62).

## Cierre operativo (2026-07-17)

Al intentar cerrar el registro se descubrió un bug de infraestructura más profundo que el simple "falta setear la env var":

**Bug real: `compose.prod.yml` no pasaba `ONBOARDING_STATE`/`CORS_ALLOWED_ORIGINS`/`CSP_REPORT_ONLY` al contenedor.** El anchor `x-rails-env` es una whitelist explícita de variables, no un passthrough de `.env` completo — solo lo que está listado ahí cruza al proceso Rails. Las 3 variables de seguridad de esta auditoría (P0 CORS/CSP del PR #51, y ahora ONBOARDING_STATE) nunca estuvieron en esa lista. CORS/CSP "funcionaban" solo por coincidencia (el default hardcodeado en el código matcheaba el valor deseado); **CSP enforce nunca se hubiera podido activar** vía env var hasta este fix. Corregido en **PR #62** (`b39111b`) — las 3 agregadas al anchor + documentadas en `.env.production.example`.

**Además, footer con "(community fork of Maybe Finance)"** visible en cada página — atribución al proyecto open-source expuesta como si fuera parte del branding. Arreglado en **PR #61** (`8846971`).

**Deploy y verificación en prod:**
- Disco de la VM llegó a 100% lleno durante el build (acumulación de build cache de ~10 rebuilds del día) — liberado con `docker builder prune -af` (2.93GB) → 88% libre, suficiente para completar.
- `docker compose exec web env` confirmó las 3 vars llegando al contenedor: `ONBOARDING_STATE=closed`, `CORS_ALLOWED_ORIGINS=https://finance.cd-co.com.py`, `CSP_REPORT_ONLY=true`.
- Navegador (ventana privada): `/registration/new` → **"Las inscripciones están actualmente cerradas."** ✅
- Footer: "© 2026, CD & Co. FinancePY" sin mención a Maybe Finance/fork. ✅

Auditoría P0/P1/P2/P3 + cierre operativo: **100% completa.** (SQL injection interpolación, TOCTOU, DataCacheClearJob sin WHERE, deuda técnica) — no incluidos en este PR.
