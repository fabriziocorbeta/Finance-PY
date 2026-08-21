---
type: meta
title: "Log de Operaciones"
created: 2026-05-05
updated: 2026-08-20
tags: [meta, log]
---

## 2026-08-20 — save | FinancePY: wave 1b cerrada, PR #74 mergeado+deployado, diseño bloquea 1c/1d

- Type: session
- Location: wiki/meta/Sesión 2026-08-20 FinancePY wave 1b cierre + PR 74 + diseño bloquea 1c-1d.md
- Wave 1b (Reglas CRUD nativo) verificada end-to-end en dispositivo físico contra prod. 3 bugs reales (serialización de defaults, inset teclado, inset nav bar).
- PR #74 de Jules (API read-only Budgets/Goals/Receivables) revisado: encontró bug de seguridad real (`receivables_scope` sin `.accessible_by`, IDOR-adyacente), corregido con test de regresión, mergeado (`e0da0cc`) y deployado.
- Usuario notó que la app nativa no respeta el design system real de FinancePY (Sure design system) — decidió explícitamente: puerto de diseño ANTES de wave 1c (CRUD completo) y wave 1d (wallet-capture). Spec aún no escrita.
- 3 prompts de CRUD (Budgets/Goals/Receivables) delegados a Jules en paralelo, corren sobre Rails puro, no tocan el módulo nativo.

---

## 2026-08-14 — save | Continuación sesión FinancePY: código Kotlin recuperado, rama equivocada, dedup + auto-categorización

- Type: session (continuación)
- Location: wiki/meta/Sesión 2026-08-13 FinancePY unificación móvil + puente SSH Tailscale + QA wallet capture.md (sección "Continuación 2026-08-14")
- Grave: todo el código Kotlin del wallet capture nunca estuvo versionado en git — vivía suelto en el `android/` gitignoreado de la notebook. Recuperado y commiteado a `native/android/wallet-listener/` en `main`.
- 2 fixes reales (script de linking, signo del webhook) habían caído en `feature/android-offline-phase1` por error en vez de `main` — movidos con cherry-pick.
- Bug real de duplicados en wallet capture (Google Wallet reposta la misma notif, sin dedup se creaba 2 veces) — arreglado con ventana de 60s por contenido.
- Auto-categorización agregada enganchando el motor de Rules ya existente de la app, no lógica nueva.
- Pendiente: usuario confirme con compra real que no duplica y categoriza.

---

## 2026-08-13 — save | Sesión 2026-08-13 FinancePY unificación móvil + puente SSH Tailscale + QA wallet capture

- Type: session
- Location: wiki/meta/Sesión 2026-08-13 FinancePY unificación móvil + puente SSH Tailscale + QA wallet capture.md
- Rama `feature/android-unified-wallet-capture` (PR #70, repo `cd-co-erp`) une Capacitor + captura Wallet nativa — resuelve parcialmente la fragmentación de 3 iniciativas móviles del 11-12/08. Build 100% CLI en WSL (Android Studio descartado explícitamente por el usuario), SDK Android nativo instalado dentro de WSL2, JDK 17→21.
- **Puente Mac↔notebook con Tailscale + SSH armado y verificado con comando real** (no solo reportado) — elimina el relay manual de copy-paste para esta rama en adelante. Notebook configurada para no dormir al cerrar la tapa.
- Patrón reforzado por tercera vez: dos pasos reportados por Gemini como "correctos" (`MainActivity.java`, conexión SSH) tenían problemas reales al verificar con comando propio.
- QA en curso: 2 bugs reales encontrados — modo avión sin fallback offline rico pese a que los archivos de Fase 1 offline-first ya están en la rama; captura de compra Wallet real (Ueno/Google Pay) no detectada, sospecha de mismatch de package name hardcodeado en `WalletNotificationListenerService.kt`. Ambos sin resolver al cierre de esta nota.
- `package-lock.json` sincronizado y pusheado (`0e2685f`) directo desde la sesión vía el puente SSH.
- Actualizado: memoria del proyecto (`project_financespy.md`)

---

## 2026-08-12 — save | Sesión 2026-08-11/12 FinancePY RN app login OAuth resuelto

- Type: session
- Location: wiki/meta/Sesión 2026-08-11-12 FinancePY RN app login OAuth resuelto.md
- Login OAuth del RN app `financespy-app` (captura Wallet) resuelto en producción real. Causa raíz: `compose.local.yml` usa `build: .`, y el comando de deploy repetido toda la sesión (`--force-recreate` sin `--build`) nunca reconstruía la imagen Docker — 4 fixes de código reales (commits `7451dc5`, `97cbd67`, `45fb334`, `c5f285b`) quedaron sin ejecutarse hasta agregar `--build`.
- Descartes reales verificados en el camino: 0 Cache Rules en Cloudflare, Service Worker/cache de browser limpiado sin efecto, cero VMs GCP corriendo (confirmado con `gcloud` directo), sin contenedor `web` duplicado. Un test que parecía decisivo (parar `web`, sitio "seguía andando") resultó ser el propio Service Worker de la PWA sirviendo cache ante un 502 — comportamiento intencional, no evidencia de otro backend.
- Descubrimiento colateral: hay **3** iniciativas móviles sin decisión tomada entre ellas (TWA/Bubblewrap, Capacitor offline-first, y este RN app) — antes se pensaba que eran 2. Brainstorming iniciado para decidir cómo conviven.
- Actualizado: memoria del proyecto (`project_financespy.md`), hot.md

---

## 2026-08-10 — FinancePY: webhook Android arreglado (2 bugs reales), automatización bloqueada en decisión de plataforma

- Bug 1 arreglado y pusheado (`5b1daba`): normalización de monto en `AndroidPurchase::WebhookProcessor` (separador de miles hipotético)
- Bug 2 arreglado y pusheado (`f20fa8d`): formato real confirmado con notificación real (`"PYG112,000 con GNB GOOGLE ••6536"`) es coma-miles, no punto — el fix anterior corrompía este caso real. Corregido.
- 503 en notebook: `ANDROID_WEBHOOK_TOKEN` no migró de la VM — resuelto seteándolo en `.env.local`
- Mapeo de 4 cuentas Wallet↔FinancePY confirmado (Ueno, Amex, Conti, GNB); cuenta GNB creada, duplicado detectado y eliminado por Fabrizio
- Investigación a fondo (con capturas reales del dispositivo): Samsung "Modos y Rutinas" no puede capturar texto de notificación como variable ni tiene acción HTTP — confirmado que ningún Android nativo puede hacer esto sin app de terceros
- Fabrizio pidió el reporte completo para investigar por su cuenta antes de decidir entre MacroDroid vs. app nativa propia vs. carga manual
- Actualizado: [[FinancePY - Spec Módulos Neto (recurrentes, notificaciones, inversiones)]], hot.md

---

## 2026-08-08 — save | Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)

- Type: session
- Location: wiki/meta/Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor).md
- From: sesión del 2026-08-05 retomada hoy para guardarla — descubrió al abrir que la VM `alejandro-vm` (donde vivía el trabajo, en un worktree sin pushear) se había apagado por la migración de hosting ya ejecutada. Se prendió la VM un momento, se pusheó la rama `feature/android-offline-phase1` a GitHub, se apagó de nuevo. Nada quedó corriendo.
- **Contradicción real encontrada, documentada en ambas páginas**: esa sesión eligió Capacitor (push nativo); una sesión posterior (2026-08-06/07) construyó el APK con TWA/Bubblewrap sin saber de esa decisión. Ver [[FinancePY — APK Android (TWA) con Bubblewrap]] y [[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]] — pendiente real: decidir a propósito cuál gana.

## 2026-08-08 — Reporte Gemini "módulos Neto" auditado contra código real: mayormente redundante; causa raíz del bug de notificaciones Wallet acotada

- **Contexto real, no capturado en el reporte**: la detección de notificaciones de Google Wallet **ya se había construido e intentado** (spec `docs/superpowers/specs/2026-07-28-android-purchase-webhook-design.md`) y no funcionó. El reporte de Gemini es una re-especificación posterior al fracaso, sin acceso al código — trata como "feature nueva" cosas que ya existen y diagnostica mal lo que sí falta.
- **Causa raíz del bug de notificaciones acotada, no confirmada todavía contra el teléfono**: arquitectura real es Tasker/MacroDroid (lee notificación) → `POST /webhooks/android_purchase` → Rails. Lado Rails completo y en prod (`webhooks_controller.rb:60`, `AndroidPurchase::WebhookProcessor`, idempotencia SHA256, tests). Sospecha principal: `BigDecimal("150.000")` da `150.0`, no `150000` — separador de miles paraguayo puede estar guardando montos 1000× menores en silencio (HTTP 200, sin error). Tabla de diagnóstico por código HTTP documentada.
- **Corrección de arquitectura**: el shell Android es **TWA con Bubblewrap** (`~/code/financespy-twa`, APK firmada `py.com.cd_co.finance.twa`), no Capacitor como decía el spec del 05/08. Un TWA no puede leer notificaciones ajenas bajo ninguna config — pero no bloquea nada porque el diseño real delega la lectura a Tasker, no a la app.
- **Auditoría de 7 áreas contra `~/code/financespy` (workflow con verificación adversarial, 4/7 completaron)**: confirmado que gran parte del reporte ya está implementado — `recurring_transaction.rb` (con detección automática de patrones y proyección "Upcoming" en dashboard), `investment.rb`/`holding.rb`/`security.rb` (cripto incluida, 10+ providers de cotización ya integrados), `budget.rb`/`category.rb`/`goal.rb` (presupuestos, ABM categorías, huchas virtuales — todo con tests), `subscription.rb` (Stripe end-to-end: checkout, portal, webhook firmado, trial 45 días), "ocultar saldos" (implementado punta a punta, 143 elementos `.privacy-sensitive`).
- **Faltantes reales identificados** (no estaban en el reporte de Gemini, salieron de leer el código): bug de `GoalPledge::Reconciler` nunca invocado por transacciones reales (pledges `transfer` quedan huérfanos), `es-PY` cargado pero inalcanzable en la UI (falta en `SUPPORTED_LOCALES`, fix de un renglón), fallback de i18n roto (`default_locale :es` con fallbacks no cae a inglés), gating Pro binario sin columna `plan`/tier, y el bloqueante comercial real: **Stripe no opera con entidades paraguayas**, acoplamiento por nombre de columna a `stripe_customer_id`, sin provider local (Bancard/PagoPar/Tigo Money).
- **Housekeeping de nombres**: a pedido del usuario, se corrió un scrub de menciones de la marca del proyecto upstream en todo el vault (11 archivos, 29 ediciones, workflow con verificación adversarial) — FinancePY es producto propio a comercializar, no puede llevar esa marca en su documentación. Identificadores literales de código (nombres de archivo, endpoints, ids DOM) se dejaron intactos a propósito — quedan como tarea aparte para renombrar en el repo `cd-co-erp`.
- Detalle completo, backlog priorizado por esfuerzo/valor y estado real de cada módulo: [[FinancePY - Spec Módulos Neto (recurrentes, notificaciones, inversiones)]] (reescrita con la auditoría, versión original de schema conservada colapsada como registro de qué se descartó).
- Corrección de infraestructura: la VM GCP se apagó **a propósito y con snapshot** (no fue el incidente accidental de la sesión anterior) — Alejandro (n8n/agente WhatsApp) estaba desactivado por reconfiguración pendiente al momento del apagado. Sin cambios de código.

## 2026-08-07/08 — FinancePY en producción real en la notebook; APK Android (TWA) armado; corte accidental de Alejandro y recuperado; bug de categoría de combustible arreglado

- **Migración a notebook ejecutada y verificada en producción**, no solo preparada: `finance.cd-co.com.py` sirviendo estable desde la notebook (i5/8GB) vía Cloudflare Tunnel, VM GCP apagada. Detalle completo en [[FinancePY - Hosting fase prueba (PC local)]] (actualizada) y [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]].
- **Corte de luz real en la notebook durante la sesión**: ~50 min de downtime. Causa raíz real (no la que reportaba Gemini): WSL2/Docker/cloudflared no arrancan solos al boot de Windows — los 4 contenedores de FinancePY sí tienen `restart: unless-stopped`, pero WSL2 mismo no se levanta sin intervención. Guía completa de arranque automático (systemd en WSL, Tarea Programada de Windows, `powercfg`) en [[FinancePY — Arranque automatico y fallback (notebook WSL2)]] — **redactada, no aplicada todavía** en la notebook.
- **APK Android real (TWA) generado con Bubblewrap** — package `py.com.cd_co.finance.twa`, funciona sin cuenta de Play Store (sideload, los $25 de Play Console solo hacen falta para publicar, no para generar el `.apk`). Keystore respaldado en Drive (`.local-secrets/android-keystores/`, contraseña NO guardada en ningún archivo — la tiene el usuario). `assetlinks.json` en `public/.well-known/` (PR #65) para que Android oculte la barra de navegador.
- **Saga de 3 rondas para el `Cache-Control` del service worker** (PRs #66, #68, #69) — vale la lección para la próxima vez que Caddy tenga que pisar un header que también setea el backend: usar el prefijo `>` (`header @sw >Cache-Control "no-cache"`), el atajo oficial documentado de Caddy para "set + defer" en un solo paso. La combinación manual `defer` + `-Cache-Control` + `Cache-Control` terminó, en producción real, sin ningún header (no duplicado, sino ausente) — confirmado con curl directo a Caddy bypaseando Cloudflare cada vez antes de dar por bueno un fix.
- **Hallazgo aparte, sin resolver todavía**: con el Cache-Control ya bien seteado en origen, Cloudflare seguía sirviendo `max-age=14400` — la config del dashboard "Browser Cache TTL: 4 hours" (Free plan) puede estar pisando el header de origen en vez de respetarlo. Pendiente cambiar a "Respect Existing Headers" y reverificar.
- **Incidente real, no simulado**: el usuario apagó la VM GCP pensando que era solo el costo de FinancePY — **tumbó también a Alejandro** (n8n + alejandro-agent + openwa-api, bot de WhatsApp con clientes reales), que seguía compartiendo la VM porque la migración a la Ryzen3/16GB decidida el 05/08 nunca se ejecutó. Detectado y restaurado (`gcloud compute instances start`) en minutos. Antes de apagar la VM de nuevo (esta vez a propósito, ya que Alejandro/Hermes están desactivados por reconfiguración pendiente): snapshot manual (`alejandro-vm-manual-20260807`) + backup aparte de `.env` real y compose files de alejandro-agent/n8n en `.local-secrets/alejandro-vm-backup-2026-08-07/`. Snapshot diario automático (`alejandro-daily-backup`) confirmado funcionando.
- **Bug real arreglado**: cargas de combustible en el módulo Flota quedaban "Sin clasificar" — `FuelLog#create_associated_entry` nunca seteaba `category_id`, y la auto-categorización por IA solo corre vía Rules del usuario, nunca automático. Fix: categoría fija "Combustible" (PR #67, mergeado, 2 tests nuevos agregados — el suite real dio 0 failures/0 errors, el único test rojo del run fue el flaky ya conocido de `settings_test.rb`, sin relación).
- Nota aparte: el "Servicio de la máquina virtual" que aparecía consumiendo RAM en el Activity Monitor de la Mac del usuario **no es la VM de GCP** — es el sandbox local (`Virtualization.framework`) que usa esta sesión de Claude Code para correr en la Mac. No se puede cerrar sin cortar la sesión.

## 2026-08-08 — Spec: módulos FinancePY inspirados en app "Neto" (recurrentes, notificaciones, inversiones)

- Creado: `emprendimientos/FinancePY - Spec Módulos Neto (recurrentes, notificaciones, inversiones).md`
- Fuente: reporte Gemini pegado por Fabrizio, analizado y estructurado (no archivado como fuente cruda)
- Propuesta schema Rails: `recurring_transactions`/`recurring_transaction_occurrences`, `holdings`/`asset_quotes`, `notification_capture_settings`/`captured_notifications`
- Verificado contra docs existentes: shell Android Capacitor ya spec'd + Fase 1 shippeada (`feature/android-offline-phase1`) — módulo notificaciones se apoya en eso, no bloqueado
- Estado: spec pura, nada implementado, nada verificado contra código real todavía
- Actualizados: emprendimientos (nueva página), index.md, hot.md

---

## 2026-08-07 — Bug documentado (sin arreglar): carga de combustible en Flota queda "Sin clasificar"

- **Síntoma:** al registrar una carga de combustible (módulo Flota de [[financespy]]/CD&Co ERP), el monto aparece en el dashboard bajo la categoría "Sin clasificar" en vez de "Transportation" o una categoría de combustible propia.
- **Causa raíz confirmada en código** (`app/models/fuel_log.rb:25-37`, `create_associated_entry`): al crear el `Entry`/`Transaction` asociado a la carga, solo se setean `name`, `date`, `amount`, `currency` — nunca `category_id`. No es un fallo silencioso, es que la asignación de categoría simplemente no está implementada en este flujo.
- **Por qué no se autocompleta sola:** la auto-categorización por IA (`AutoCategorizer`, `family.auto_categorize_transactions_later`) tiene un solo punto de entrada en toda la app: `app/models/rule/action_executor/auto_categorize.rb`, que solo corre cuando una Rule del usuario con acción `auto_categorize` se dispara. Los entries creados por `FuelLog` no pasan por ningún matching de reglas automáticamente.
- **Gap adicional:** `fuel_logs_controller.rb:33`, `fuel_log_params` permite `:liters, :cost, :odometer, :account_id, :logged_at, :notes` — ni siquiera existe la opción de elegir categoría a mano al cargar combustible.
- **Fix recomendado (no aplicado todavía):** opción simple — asignar una categoría fija (ej. "Transportation") en `create_associated_entry` al crear el entry. Opción más flexible — agregar `category_id` a los params permitidos y al form de carga de combustible, para que el usuario elija (o quede con default si no elige).
- Sin tocar código a pedido — solo queda documentado para decidir cuándo priorizarlo.

## 2026-08-05 — FinancePY: entorno dev local no funcional en Mac
- Type: emprendimiento
- Location: wiki/emprendimientos/FinancePY — entorno dev local bloqueado en Mac.md
- From: intento de previsualizar FinancePY en vista iPhone; sin proyecto Xcode (es Rails web), se probó levantar dev local y falló por Ruby/bundler/Postgres/Docker faltantes — se usó prod (finance.cd-co.com.py) en browser resizeado en su lugar.

## 2026-08-05 — Arquitectura de hosting de 3 máquinas cerrada; investigación a fondo de n8n en Agente IA CD&Co (dos integraciones, una en prod, otra abandonada)

- **Decisión de infraestructura cerrada:** FinancePY → notebook (i5 7ma gen, 8GB, 832GB libres, ya confirmada); n8n+alejandro-agent+openwa-api ([[Agente IA CD & Co]]) → **PC de escritorio dedicada, Ryzen 3, 16GB RAM**; Railway pasa a rol de fallback para ambos stacks, no primario. Resuelve el pendiente abierto desde el 18/07 en [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]] sobre qué hacer con los 3 servicios que compartían la VM GCP.
- **Sin confirmar:** la PC Ryzen 3/16GB podría ser la misma máquina que el HP EliteDesk 705 G4 SFF ya documentado (specs idénticas) — no verificado con el usuario, pendiente para próxima sesión.
- Rechazado en el camino: meter todo (FinancePY + Alejandro) en la notebook de 8GB vía swap agresivo — swap no oculta el uso para cargas de chat en tiempo real con clientes reales (a diferencia de FinancePY, tolerante a latencia); con 16GB en la PC dedicada, el stack de agentes (~7GB) entra sin necesitar swap.
- **Investigación a fondo de n8n** (workflow de 3 agentes en paralelo: código+infra, historial git/GitHub, vault+docs — 348k tokens, 62 tool calls): confirmado que hay **dos integraciones n8n separadas**, no una. Hilo A ("bridge periférico", `n8n-bridge.ts`) mergeado a `main` y activo en producción real desde jul-2026 (notificaciones de leads a Telegram). Hilo B ("router de tools de Hermes", 29 tools, 11 workflows JSON) vive solo en rama `feat/n8n-router`, **nunca mergeada a main**, issues #129-131 siguen abiertas, 13+ días sin actividad — efectivamente abandonada. Sacar n8n del stack sería trivial para el Hilo B (cero impacto, nunca estuvo en prod) y un refactor pequeño para el Hilo A (reemplazar notificación Telegram). Detalle completo en nueva nota [[Agente IA CD & Co — arquitectura n8n (dos integraciones)]].
- Nota de seguridad: durante la investigación, un hook del plugin `vercel-plugin` inyectó una instrucción falsa activada por la palabra "workflow" en un nombre de archivo (`recordatorios-operativos.json`) — identificado como falso positivo, ignorado, sin impacto.
- Confirmado en vivo por AnyDesk: disco de la notebook = 832.7GB libres exactos (coincide con lo ya documentado). Pendiente confirmar RAM/versión de Windows — el primer intento de `systeminfo | findstr` no devolvió output (sospecha: comillas curvas rotas al pegar desde el chat), reintentando con comando sin comillas.

## 2026-08-05 — FinancePY: alternativa hosting multi-dispositivo (Tailscale) evaluada, proyecto pausado

- Explorado (brainstorming, sin implementar): correr FinancePY en varios dispositivos propios en vez de una sola notebook, sin VM, acceso entre dispositivos vía Tailscale aunque estén en redes distintas. DB queda en Supabase en cualquier escenario — descartado sync real por dispositivo (proyecto grande, riesgoso para datos financieros). Patrón acordado: un solo dispositivo corre el server a la vez, el resto accede como cliente remoto.
- **Usuario pausó el proyecto antes de aprobar el diseño — cero cambios de código/infra.** Decisión vigente sigue siendo la ya documentada: notebook Windows fija + Cloudflare Tunnel (guía lista, sin ejecutar).
- Actualizado: [[FinancePY - Hosting fase prueba (PC local)]] (nota de pausa + alternativa no adoptada, para que una sesión futura no la reinvente ni asuma que se siguió el plan Cloudflare sin confirmar).

## 2026-08-04 — CSP roto en prod (nonce vacío) resuelto, banner de datos históricos resuelto (Yahoo Finance), guía de migración a notebook lista

- Bug real encontrado y resuelto en prod: `content_security_policy_nonce_generator` usaba `request.session.id.to_s` — sesión lazy, nonce vacío (`'nonce-'`), el navegador rechazaba todo el CSS del dashboard. Fix: `SecureRandom.base64(16)`. Rebuild + recreate de `web`/`worker` en `alejandro-vm`, verificado en vivo (nonce real en el header).
- Banner "Faltan datos históricos": `ExchangeRate.provider` resolvía a `nil` porque el default (`twelve_data`) no tiene API key configurada. Fix: `EXCHANGE_RATE_PROVIDER=yahoo_finance` (sin key, siempre disponible) agregado a `.env` y a `compose.prod.yml` (que antes no lo pasaba al container — mismo patrón del bug de whitelist explícita de env vars ya documentado en [[Sesión 2026-07-16 FinancePY security fixes deploy]]). Verificado con `family.missing_data_provider?` → `false`.
- **Ambos fixes quedaron aplicados en la VM pero sin commitear a git** — pendiente real antes de cualquier migración (ver guía).
- Retomada la migración de hosting a PC local (decidida 2026-07-30, nunca ejecutada): specs reales de la máquina confirmados — **notebook i5 7ma gen, 8GB RAM, 832GB libres**, no el HP EliteDesk (16GB) que asumía el plan original del 18/07. Ajustado el análisis de margen de RAM (más ajustado con 8GB) en [[FinancePY - Hosting fase prueba (PC local)]].
- Verificado que el trabajo de infraestructura del 18/07 ya está listo en el repo (`compose.local.yml`, `Caddyfile.local`, `docs/cloudflared-config.yml.example`) — solo faltaba ejecutarlo. Encontrado y corregido un gap: `compose.local.yml` tampoco pasaba `EXCHANGE_RATE_PROVIDER` al container (mismo bug que en prod).
- Escrita guía ejecutable paso a paso para hacer la migración a mano en el teclado de la notebook (no por AnyDesk, que viene fallando el control remoto): [[FinancePY — Guía paso a paso migración VM a notebook Windows]]. No ejecutada todavía — a pedido del usuario, solo preparación.
- **Preparación avanzada al máximo posible desde acá (sin acceso a la notebook):** los 2 fixes de arriba se sincronizaron a git (commits `73a5ac0` en `fabriziocorbeta/cd-co-erp`). Al pushear se descubrió que un commit del 30/07 (`5656158`, límites de memoria + fix `WEB_CONCURRENCY=1` para el mismo escenario de "PC compartida") nunca se había bajado a la VM ni desplegado en prod — quedó solo en GitHub. Portado el mismo fix a `compose.local.yml` (que no lo tenía, commit `5f3666f`) para que la notebook no repita el OOM ya visto una vez en el intento de Render. Corregida también la guía: el paso de clonar el repo asumía usuario/contraseña de GitHub, que no funciona desde 2021 (repo privado) — reescrito con `gh auth login` (device flow, más robusto al problema real de AnyDesk: falla el input de comandos, no la pantalla).
- **Pendiente real, no decidido:** el fix de OOM del 30/07 sigue sin desplegarse en la VM que corre prod hoy (commiteado pero nunca rebuildeado) — se dejó así a propósito para no sumar un redeploy no pedido en la misma sesión.
- **Cloudflare Tunnel `financespy-local` creado** (ID `3c395573-45f7-4313-8c8b-a37e924517e6`), a pedido explícito del usuario. La VM ya tenía el certificado de cuenta autorizado (por el tunnel `alejandro` existente de n8n/agente) — no hizo falta login OAuth de nuevo. Credenciales + config quedaron listos en `~/.cloudflared/` de la VM, pendiente de copiarse a la notebook (Paso 5 de la guía). DNS de `finance.cd-co.com.py` **no se tocó** — sigue apuntando a la VM, el corte queda para el Paso 6, explícitamente el único paso no reversible al instante.

## 2026-07-30 — Fix real: opción de foto de recibo no aparecía (accept list incompleto); intento Render $0 descartado por OOM, pivote a PC local

- Fix real deployado en prod (commit `aad575d`): `document_upload_supported_extensions` en `imports_controller.rb` armaba el `accept` del file picker solo desde `adapter.supported_extensions` (pgvector: solo `.pdf`+texto) — `.jpg/.jpeg/.png` nunca entraban a la lista, por eso la opción de subir foto de recibo no aparecía en ningún dispositivo. El fix de la sesión anterior (mapeo MIME) nunca podía dispararse porque las extensiones no estaban ni siquiera en la lista base. Confirmado en 10 tests + verificado vivo en prod (`service-worker` v5, curl 302).
- Intento de bajar costo de hosting FinancePY a $0 en Render.com: Redis free desplegado OK, pero Background Worker no tiene tier gratis real (mínimo $7/mes) pese a la tabla de precios pública. Workaround con `foreman` (web+Sidekiq en 1 proceso) quedó commiteado (`d3665aa`, repo `cd-co-erp`) pero el deploy real tira OOM en la instancia free (512MB) corriendo Puma cluster + Sidekiq juntos.
- Decisión: abandonar Render, migrar el server a una PC local en cambio. Detalle completo, pendientes reales y riesgos en [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]].

## 2026-07-27 — PDF de extractos: 3 bugs reales resueltos en cadena, extracción de transacciones sigue rota (capacidad del modelo)

- Bug 1 (real, resuelto): CSP bloqueaba el submit del form "Importar documento" — `onchange` inline, nonces no cubren atributos de evento. Fix con Stimulus. De paso se arreglaron 5 casos más del mismo patrón en el repo (confirm dialogs de doorkeeper, reload button, stopPropagation en snaptrade/indexa)
- Bug 2 (real, resuelto): faltaba `poppler-utils` en Docker para el fallback OCR — no afectó el PDF real del usuario (tenía texto extraíble) pero era un hallazgo real del audit externo
- Bug 3 (real, resuelto — causa real de "no me lee el PDF"): el modelo NVIDIA Nemotron nano a veces devuelve JSON válido pero con la primera clave corrupta (`.document_type` en vez de `document_type`) — clasificación caía silenciosa a "other". Fix: normalizar claves
- Bug 4 (NO resuelto): con clasificación ya correcta, la extracción de las transacciones individuales devuelve vacío consistentemente — 3 capas de retry agregadas (contenido vacío, timeout de red, array vacío específicamente) no lo resolvieron. Es capacidad real del modelo nano para esta tarea, no un bug de código. Probado con modelo más grande (Nemotron 49B) — demasiado lento, timeout en las 3 pasadas
- Pendiente real: decidir modelo más grande + subir timeout del cliente (viable en job async) vs. rediseñar prompt/chunking para el modelo nano
- Bug menor sin resolver, encontrado en el camino: SMTP no configurado en la VM, el mail de aviso de import falla y reintenta sin parar
- Ver detalle completo en [[Reporte de modificaciones — FinancePY 2026-07-23]] (sección agregada al final)

## 2026-07-25 — CLS real resuelto (viewport-height race), audit externo verificado 6/6, repo privado

- CLS del login: 0.231 → 0-0.006 (score 84→97-99). Root cause real (no el logo/fuente como parecía): `viewport_controller.js` fijaba `--app-height` post-paint vía Stimulus, reemplazando `100dvh` — fix inline+sync después de `<meta viewport>`. Encontrado con probe de Puppeteer + PerformanceObserver, no con el resumen de Lighthouse
- Bonus: `dark_mode_check`/`privacy_mode_check` bloqueados por CSP sin nonce desde el 18/07 — nunca funcionaron en prod, ya arreglados
- Auditoría externa (otra IA/sesión) sobre `cd-co-erp` verificada contra código real antes de actuar: 6/6 claims ciertas — repo público+AGPL+README contradictorio (ahora privado), CI roto (arreglado), **causa real de "no me lee el PDF"**: faltaba `poppler-utils` para el fallback OCR (arreglado), defaults inseguros de compose, `config.hosts` sin usar, imágenes Docker sin pin — todo corregido y deployado
- Ver detalle completo en [[Reporte de modificaciones — FinancePY 2026-07-23]]

## 2026-07-23 — PWA offline-first deployada, splash Android/iOS optimizado, audit total ejecutado

- PWA offline-first para Ventas completa (6 tareas): cache runtime + cola IndexedDB + Background Sync, deployado y verificado en `alejandro-vm`
- Splash/loading screen: icono maskable corregido en Android (`18c02cf`), optimización de carga percibida en ambas plataformas
- Auditoría total FinancePY ejecutada (Fases 1/2/4/5, 9 min con subagentes): Fase 1 y 2 limpias, Fase 4 bloqueada (bundler-audit sin acceso a advisory-db), Fase 5 con 5 hallazgos
- Fix N+1 en `SalesController#set_sale` + idempotencia (`client_request_id` + `Rails.cache`) en cola offline de Ventas, deployado (`9f78a23`) — resuelve duplicados por reintento/concurrencia/doble-click
- Ver detalle completo en [[Reporte de modificaciones — FinancePY 2026-07-23]]

## 2026-07-23 — Reporte de modificaciones registrado

- Nueva página: [[Reporte de modificaciones — FinancePY 2026-07-23]] — changelog estructurado de todos los commits, cambios de infra y decisiones de la sesión (FinancePY + alejandro-agent + VM GCP)

## 2026-07-23 — FinancePY: ventas (nota+remito), CSP bug, seguridad agente, hosting definitivo, modelo IA

- Modelo del asistente de FinancePY cambiado a `nvidia/nemotron-3-nano-30b-a3b` tras barrida verificada de 12+ modelos NVIDIA NIM (Nemotron/Llama/DeepSeek/Gemma/MiniMax/GLM/Mistral/Qwen) — único correcto Y razonablemente rápido. Modelo anterior (`llama-3.1-8b`) confirmado con error real de cálculo, no era queja infundada
- Hallazgo: bajo carga real (tool-calling multi-ronda + prompt completo) la latencia sube a 15-31s — decisión del usuario: mantener por corrección, streaming queda como pendiente a evaluar para mejorar percepción

- Nueva página: [[Sesión 2026-07-22-23 FinancePY ventas + seguridad + migración]]
- Sales: nota de venta + nota de entrega shippeadas (campos `delivery_address`/`delivery_date`/`carrier`), rediseño tipo Shopify
- Bug real: CSP enforce rompía click-en-fila en 4 vistas (onclick inline) — fix vía Stimulus
- Decisión de hosting confirmada: FinancePY → PC local, agentes → Railway, VM GCP se desactiva por completo (crédito vence)
- VM disco redimensionado 30GB→50GB (fix de raíz al problema recurrente de espacio en builds)
- **Hallazgo de seguridad real en alejandro-agent**: `/webhook`/`/health/reconnect` sin auth, expuestos a todo internet — arreglado con HMAC signature + secreto, deployado y verificado
- Migración a PC local preparada pero no ejecutada esta sesión (requiere acceso manual del usuario a esa máquina)
- Ajustado `compose.local.yml`: techo bajado a ~3.1GB RAM / ~1.6 cores (de 4 disponibles) para no afectar a otras personas usando la PC
- Migración pospuesta a mañana por decisión del usuario ("ya es muy tarde") — **riesgo marcado explícitamente**: el crédito GCP vence hoy 23/07, "mañana" cae después del vencimiento
- **Próximo paso identificado, no iniciado:** proyecto PWA offline-first para FinancePY (app shell cacheado + IndexedDB + sync engine) — motivación real no es la latencia (ya resuelta con la migración a PC), es que el usuario quiere que la app se sienta nativa en el celular con uso offline real. Base existente es mínima (`app/views/pwa/service-worker.js` solo cachea una página "sin conexión" estática, no hay IndexedDB ni sync). Brainstorm arrancado 2026-07-23.

## 2026-07-18 — Decisión: hosting FinancePY fase de prueba en PC local

- Nueva página: [[FinancePY - Hosting fase prueba (PC local)]]
- FinancePY (fase de prueba, no comercial aún, varios meses de testing con pocos usuarios) migra su hosting de la VM GCP (Iowa, alta latencia) a la PC de casa (HP EliteDesk 705 G4, Ryzen 3 PRO 2200G, 16GB) — costo $0 durante validación
- Docker con límites `mem_limit`/`cpus` (no `deploy.resources`, ese formato solo aplica en modo Swarm) para no afectar uso normal de la PC
- Cloudflare Tunnel para exponer sin abrir puertos ni depender de IP dinámica
- Backups: `pg_dump` directo a carpeta sincronizada de Google Drive Desktop (opción A) o `rclone` (opción B) — sin consumir RAM extra
- Agentes (n8n + alejandro-agent + openwa-api) se descartó Cloudflare Workers por restricción técnica dura: openwa-api necesita sesión persistente de Chromium headless para WhatsApp Web, incompatible con V8 Isolates. Van a **Railway** — estimado $10-25 USD/mes always-on, verificar en railway.app/pricing
- VM GCP se **desactiva por completo** (no fallback) — Railway + PC local cubren el 100% de la función, corta el costo íntegro de la VM
- Fallback de FinancePY (si la PC cae) también es **Railway**: segunda instancia en modo dormido/escalada a 0, restaura backup de Drive ante activación — Railway concentra rol primario (agentes) y standby (FinancePY), estimado total ~$10-27 USD/mes
- Sleep/wake en agentes solo parcial: n8n y alejandro-agent sí pueden dormir (webhook-triggered), **openwa-api no** — mantiene conexión persistente tipo WebSocket para WhatsApp Web, dormir la sesión la desconecta y pierde mensajes entrantes (no hay cola de espera)
- Acceso remoto Mac→PC vía RDP (nativo Windows 10 Pro) + Tailscale (evita exponer RDP a internet directo)
- Al comercializar: migración definitiva a São Paulo (southamerica-east1), resuelve latencia real de raíz

# Log de Operaciones

## 2026-07-18 update | FinancePY — cierre total sesión de auditoría + diagnóstico performance
- PR #63 (7fa91c5): CSP report_uri agregado (nunca estuvo seteado, cero evidencia posible antes de esto), CSP_REPORT_ONLY=false activado en prod
- Test suite: 152 fallas → 0 (PRs #54-58), causa raíz principal: default_locale :es en prod vs families.locale default "en" en schema
- Bugs reales de producto arreglados en el camino: Money#round faltante (rompía IVA), índice recurring_transactions obsoleto, Invitation borrada de invitaciones vigentes, símbolo Guaraní ₲ faltante, memory leak JS file_upload_controller, FamilyResetJob incompleto (no borraba tablas ERP propias)
- P2/P3 cerrados (PR #59/#60): README real, footer sin fork (PR #61), casi-error propio revertido a tiempo (DataCacheClearJob)
- Diagnóstico de performance real: 2 PDFs de Kimi.ai con contenido fabricado (tablas/columnas inventadas) descartados tras verificar contra DB real (380 índices existen, no 0). Causa real medida: Rails renderiza en 200ms, ~450ms restantes son latencia geográfica Iowa↔Paraguay. Evaluando mover VM a São Paulo antes de comprometerse a proyecto PWA
- Disco de la VM lleno 2 veces en la sesión — comparte con n8n/alejandro-agent/openwa-api, no es solo FinancePY
- CI 100% verde, branch protection activa, 13 PRs mergeados en total (#51-63)

## 2026-07-17 fix | FinancePY — cierre operativo de la auditoría (verificado en prod)
- PR #61 (8846971): footer "community fork of Maybe Finance" eliminado
- PR #62 (b39111b): bug real — compose.prod.yml no pasaba ONBOARDING_STATE/CORS_ALLOWED_ORIGINS/CSP_REPORT_ONLY al contenedor (whitelist explícita, no env_file passthrough). CSP enforce nunca se había podido activar por esto.
- VM: disco 100% lleno durante el deploy (build cache acumulado), liberado con docker builder prune (2.93GB) → 88%
- Verificado en prod: registro cerrado ("Las inscripciones están actualmente cerradas"), footer limpio, env vars confirmadas dentro del contenedor
- Auditoría FinancePY 2026-07-14 → 100% completa

## 2026-07-16 update | FinancePY — auditoría P3 + branch protection + cierre de sesión
- PR #60 mergeado (d591cbe, --admin por flake pre-existente confirmado sin relación): memory leak JS, error tragado en DestroyJob, FamilyResetJob completado con tablas ERP faltantes
- Branch protection activado en `main`: lint/scan_ruby/test/security-scan requeridos
- `financespy` schema Supabase verificado: cero funciones custom, sin riesgo IDOR
- Bug nuevo backlog: `test/system/settings_test.rb` flaky (mock leak entre workers paralelos)
- `auth_leaked_password_protection`: sin tool MCP disponible, queda manual para Fabrizio
- Sesión de auditoría FinancePY + CD&Co ERP cerrada — ver resumen final en [[Sesión 2026-07-16 FinancePY security fixes deploy]]

## 2026-07-16 update | FinancePY — auditoría P2 cerrada
- PR #59 mergeado (7fa4efd): README real (era boilerplate del upstream sin adaptar), 5 ítems P2 verificados como falsos positivos o ya mitigados
- Nota de proceso: casi "arreglé" DataCacheClearJob sin chequear el test suite existente primero, tuve que revertir — el test ya documentaba el comportamiento como intencional

## 2026-07-16 fix | CD & Co ERP — IDOR crítico en RPC Supabase (resuelto)
- Type: source
- Location: wiki/emprendimientos/CD & Co ERP — IDOR crítico en RPC Supabase (resuelto).md
- From: auditoría Supabase durante debugging de suite FinancePY; 9 funciones SECURITY DEFINER sin auth.uid() check, explotables por anon; migración aplicada y verificada en prod

## 2026-07-16 save | Migración hosting FinancePY — análisis Cloudflare vs alternativas
- Type: synthesis
- Location: wiki/emprendimientos/Migración hosting FinancePY — análisis Cloudflare vs alternativas.md
- From: crédito GCP por acabarse; Cloudflare Agents no sirve para Rails (sí para el agente WhatsApp); recomendación Hetzner CX22 ~€4.50/mes, plan de 6 pasos

## 2026-07-16 update | Sesión 2026-07-16 FinancePY security fixes deploy
- CI de main restaurado: PR #52 + rubocop VM (b210ab5) + PR #53 (brakeman.ignore con fingerprints reales vía workflow temporal + exclusiones pipelock)
- lint/scan_ruby/security-scan verdes por primera vez; test rojo por bugs reales (Money#round ×6, Plaid ×15)

## 2026-07-16 save | Sesión 2026-07-16 FinancePY security fixes deploy
- Type: session
- Location: wiki/meta/Sesión 2026-07-16 FinancePY security fixes deploy.md
- From: verificación + PR #51 (commit 1fdcdb2) + deploy a prod de los fixes P0/P1 de seguridad FinancePY; reporte inflado (3 de 5 P0 reales), verificación runtime CORS/CSP/rate-limit OK

## 2026-07-14 ingest | FinancePY — Auditoría de seguridad y code smells (75 hallazgos)

- Type: source (reporte externo triaged)
- Location: `wiki/emprendimientos/financespy-auditoria-seguridad-2026-07-14.md`
- From: reporte auto-generado en máquina externa (`/home/z/my-project/docs/analisis-puntos-debiles-sure-erp.md`)
- Triage: 5 P0 reales (CORS wildcard, CSP comentada, admin guard sin return, TestController prod, sin rate limit login), 3 P1 XSS, P2 a confirmar contra código, P3 backlog. Pendiente: verificar contra código real y armar PRs en sesión aparte.

## 2026-07-03 — CD & Co ERP puesta a punto + FinancePY: business mode toggle

- ERP (branch `version-1.1.0`): fix deploy Vercel roto (bypaseado git-integration con `vercel --prod --yes` manual), PWA instalable (iconos reales + manifest correcto), hardening Supabase (RLS gaps, FKs, performance `auth.uid()`, tabla `accounts` nueva)
- FinancePY: fix bug de guardado silencioso en edición masiva de transacciones (Date field atrapado en `<details>` cerrado), fix contraste de logo en sidebar (light/dark theme)
- FinancePY: shippeada fundación de "Business Mode Toggle" (commit `a80f2f6`) — primer sub-proyecto de portar los 4 módulos de negocio del ERP a FinancePY como premium, gate de un solo toggle admin. Deployado y verificado en producción (GCP VM `alejandro-vm`)
- Pendiente: sub-proyectos 2-5 (Inventario, Ventas, Pedidos, Flota); soporte multi-familia (deferido)
- Ver: [[FinancePY - Módulos Premium ERP]]

## 2026-05-19 — Agente IA CD & Co. v1 corriendo local

- Instalado OpenWA (Docker) como gateway WhatsApp
- Agente Express+TypeScript conectado a Claude Haiku 4.5 con prompt caching
- Identidad: Alejandro, vendedor humano de CD & Co.
- Anti-ban: delay humano 1.5s–8s proporcional al largo de respuesta
- OWNER_ONLY_MODE=true — en entrenamiento, solo responde a Fabri
- Contexto real del negocio en el prompt: marcas, precios, envíos, garantía
- Pendiente: precios exactos por modelo, medios de pago, persistencia sesión
- Ver: [[Agente IA CD & Co.]]

Registro cronológico append-only. Nuevas entradas van ARRIBA. No editar entradas pasadas.

---

## 2026-07-07 save | Sesión 2026-07-07 Ecosistema IA
- Type: session
- Location: wiki/meta/Sesión 2026-07-07 Ecosistema IA.md
- From: sesión fundacional — clon de Fable, base de conocimiento del negocio, ecosistema IA de 3 niveles
- Además: [[Proyectos de Claude Chat]] actualizado con nota de versión "minuto 1" autocontenida

## 2026-07-07 — Recurso: Proyectos de Claude Chat

- Creado en recursos/: [[Proyectos de Claude Chat]] — base común + 4 proyectos (Tienda, Contenido, Agencia IA, Decisiones)
- Arquitectura de 3 niveles definida: Claude Code (verdad) → Proyectos claude.ai (chat con contexto) → Gems (volumen)

## 2026-07-07 — Recurso: Gems de Gemini

- Creado en recursos/: [[Gems de Gemini]] — 4 instrucciones listas (Redactor, Asesor de Ventas, Analista de Negocio, Investigador de Mercado) + flujo Gem → vault → Gem
- División de trabajo definida: Claude = vault/código/decisiones; Gems = borradores/volumen/investigación

## 2026-07-07 — Rubros de negocio: relojes, perfumes, agencia IA

- Creado en emprendimientos/: [[Tienda Online CD & Co]] (relojes ahora, perfumes próximamente)
- Creados en aprendizaje/: [[Ecommerce de Relojes]], [[Ecommerce de Perfumes]], [[Agencias de IA]]
- Estrategia registrada: tienda como laboratorio → agentes propios → agencia de IA productizada
- Index, hot cache y memoria persistente actualizados

## 2026-07-07 — Poblado inicial del vault

- Creados en emprendimientos/: [[financespy]], [[CD & Co ERP]], [[Agente IA CD & Co]]
- Creado en intel/: [[Fable 5 pago por uso]]
- Creados en aprendizaje/: [[Dirección de Modelos IA]], [[Diseño de Subagentes]], [[Contenido para Redes]]
- Index y hot cache actualizados
- Memoria persistente de Claude actualizada (project_sistema_vault)

## 2026-07-06 — Ingest: fable-clon-skill

- Fuente: ~/Downloads/clon.pdf (guía "CLON — El Playbook Completo", jul 2026)
- Creado: [[fable-clon-skill]] en recursos/ — hábitos de razonamiento de Fable 5 destilados como SKILL.md (reglas, loop, checklists SaaS/subagentes/negocio/contenido, criterios de terminado, anti-patrones)
- Index actualizado

## 2026-05-17 — WhatsApp AgentKit: instalación y setup

- Clonado `https://github.com/Hainrixz/whatsapp-agentkit.git` → `03 Emprendimientos/03 Agente WhatsApp/`
- Python 3.10.11 insuficiente → instalado Python 3.13.13 via `brew install python@3.13`
- `start.sh` pasó: Python 3.13.13 OK + Claude Code OK
- Wiki: creada [[WhatsApp AgentKit — Setup]]
- **Próximo paso:** abrir Claude Code en esa carpeta y correr `/build-agent`

---

## 2026-05-17 — CRM Social Hub Fase 1: hardening production-correct

- Confirmado stack Supabase (descartado Firebase: CRM relacional + costo Firestore por-read + RLS ya escrito)
- `eslint.config.mjs` flat config + dep `@eslint/eslintrc` (build/lint referenciaba sin config)
- Boundaries UX (evitan pantalla blanca): `app/loading.tsx`, `app/not-found.tsx`, `app/(app)/loading.tsx` skeleton, `app/(app)/error.tsx` client reset
- **CSV import** (item roadmap F1 faltante): `contactos/actions.ts::importContacts` + parser CSV con comillas/comas + `_components/import-csv.tsx` (file + paste + ejemplo), valida Zod por fila
- **Edit contacto**: `updateContact` existía sin UI → `[id]/_components/edit-contact.tsx` slide-over prefilled
- `contactos/page.tsx`: botón Filtrar placeholder → ImportCsvButton (fix import `Filter` roto)
- `vercel.ts` deploy config (`@vercel/config/v1`) + dep `@vercel/config` + cron placeholder F4
- Skills hooks bootstrap/next-upgrade = advisory pattern-match; next@15.1.0 pin intencional, no upgrade

**Estado F1:** production-correct. Operable post-deploy DB (solo falta infra externa Supabase).

---

## 2026-05-17 — Agente IA CD & Co.: framework ventas + leads + wiki

Implementación completa del agente WhatsApp para CD & Co. en 3 sesiones:

**Sesión 1 — Arquitectura base:**
- Scaffold `cdco-agent/` con Express + Anthropic SDK + Supabase
- Dual-mode: SECRETARY_PROMPT (clientes) / ASSISTANT_PROMPT (Fabri)
- Prompt caching `cache_control: ephemeral` en system block
- FAQ router: intercepta horario/garantía/ubicación/pago/envío/saludo (0 tokens)
- Meta Cloud API (no Twilio) — $0 ≤1000 conv/mes

**Sesión 2 — Herramientas de negocio:**
- `tools/products.js` — search_products (filtros model/brand/price/stock), create_quote
- `tools/payments.js` — request_payment (texto bancario), confirm_payment, get_pending_payments
- `tools/delivery.js` — schedule_delivery, get_pending_deliveries, confirm_delivery
- `controllers/messages.js` — orquestador con loop de hasta 5 tool calls, métricas tokens/cache
- `migrations/001_initial.sql` — 6 tablas: products, customers, conversations, quotes, payments, deliveries

**Sesión 3 — Framework ventas + leads:**
- `utils/prompts.js` — SECRETARY_PROMPT reescrito con framework 6 fases:
  - Fase 1: Calificar (1-2 preguntas, inferir presupuesto)
  - Fase 2: Crear Deseo (specs → beneficios, social proof, max 2 opciones)
  - Fase 3: Manejar Objeciones (5 scripts: precio, lo_piensa, comparando, no_me_gusta, sin_efectivo)
  - Fase 4: Cerrar (técnicas: asuntiva, elección, urgencia, directa)
  - Fase 5: Pago (create_quote → request_payment)
  - Fase 6: Entrega (schedule_delivery)
- `tools/leads.js` — NUEVO: capture_lead / get_hot_leads (agrupado por objeción) / mark_lead_contacted
- `migrations/001_initial.sql` — tabla `leads` añadida (objeción enum, upsert on phone)

**Wiki creada:**
- Creado: `emprendimientos/agente-ia-cdco.md` — arquitectura completa
- Creado: `emprendimientos/agente-ia-costo-zero.md` — estrategia $0
- Creado: `aprendizaje/agente-ia-ab-testing.md` — plan experimentos A/B
- Creado: `decisiones/decision-agente-ia-modelo.md` — por qué Haiku 4.5 + caching
- Actualizados: emprendimientos/_index.md, index.md, hot.md, log.md

**Estado:** código completo. Pendiente deploy Railway + webhook Meta.

---

## 2026-05-15 — CRM Social Hub Fase 1 (continuación): UI operable

- Añadido `supabase/seed-auth-trigger.sql` — trigger `on_auth_user_created` auto-crea org + profile + pipeline default al signup
- Server actions completas:
  - `contactos/actions.ts`: createContact / updateContact / deleteContact (Zod validation)
  - `contactos/[id]/actions.ts`: addActivity (note/call/email/meeting/task/message)
  - `pipeline/actions.ts`: createDeal + moveDeal (auto-marca won/lost por stage)
  - `_actions/auth.ts`: signOut
- Componentes cliente nuevos:
  - `contactos/_components/contact-drawer.tsx` — slide-over form con 9 campos + validación
  - `contactos/[id]/_components/activity-composer.tsx` — composer inline timeline
  - `pipeline/_components/new-deal-button.tsx` — modal con selects contacto/stage
  - `pipeline/_components/kanban-board.tsx` — dnd-kit drag-drop + optimistic update + DragOverlay
  - `_components/sign-out.tsx` — form server action
- Páginas wired:
  - `contactos/page.tsx` — botón funcional, links a detalle
  - `contactos/[id]/page.tsx` — info contacto + timeline actividades + sidebar metadata
  - `pipeline/page.tsx` — kanban dinámico, modal nuevo deal, guard si no hay contactos
  - `(app)/layout.tsx` — sign-out button + nombre org en sidebar
- README actualizado: orden estricto SQL (schema → trigger), flujo signup auto-provisión
- Note técnica: Next 16 hint `middleware.ts → proxy.ts`. Stay en `middleware.ts` porque pin `next@15.1.0`. Migrar en Fase 4-5.

**Estado F1:** completamente operable — login → signup → auto-org → crear contacto → crear deal → drag-drop kanban → registrar actividades → sign-out.

---

## 2026-05-15 — Nuevo proyecto: CRM Social Hub (Fase 1 scaffold)

- Creado: `emprendimientos/CRM Social Hub.md`
- Creado: `docs/crm-roadmap-phases.md` — roadmap 5 fases (F1 operable en 2 sem)
- Creado: `docs/crm-dashboard-design.html` — prototipo visual Enterprise SaaS (Indigo/Violet)
- Scaffold completo `crm-app/`: Next.js 15 + Supabase SSR + Tailwind + Lucide
  - Schema SQL completo: 9 tablas + RLS multi-tenant por `org_id` + función `current_org_id()` + seed pipeline default
  - Auth: login email/pass + magic link + middleware gate global
  - Páginas: dashboard, contactos (lista + server actions), pipeline (kanban), integraciones (cards F2/F3)
  - Server actions con validación Zod
- Stack confirmado: Next 15.1 + Supabase + Vercel Fluid Compute
- Roadmap: F1 (1-2sem CRM núcleo) → F2 (WA Cloud API) → F3 (IG+FB Meta OAuth) → F4 (social metrics) → F5 (IA/auto)
- Bloqueador crítico: verificación Meta Business Manager (3-5 días) — iniciar YA
- Actualizados: emprendimientos/_index.md, index.md, hot.md

---

## 2026-05-06 — Ingest: CD&Co ERP Módulo de Exportación

- Creado: `emprendimientos/CD&Co ERP - Módulo de Exportación.md`
- Módulos implementados: `data-exporter.js` (JSON, 20 tablas), `sure-csv-exporter.js` (CSV formato FinancePY)
- Serverless Vercel: `api/export-data.js`, `api/export-sure-csv.js`
- Frontend: 2 botones en panel Seguridad & Respaldos (index.html + backup-ui.js)
- Commits: b007df2, 253baa1, 19f30e4
- Actualizados: emprendimientos/_index.md, index.md, hot.md

---

## 2026-05-05 — Ingest: Comparativa Pasarelas de Pago Paraguay

- Creado: `intel/Pasarelas de Pago Paraguay - Comparativa 2025.md`
- Fuentes analizadas: T&C UPay (contrato privado, estimaciones), T&C Dinelco (BEPSA), T&C PagoPar (Grupo M)
- Artefacto: `comparacion-pasarelas-py.html` — gráfico interactivo 5 tabs (Desktop)
- Scores: PagoPar 57/80 · UPay 49/80 · Dinelco 43/80
- Actualizados: intel/_index.md, index.md, hot.md

---

## 2026-05-05 — Scaffold inicial

- Vault creado: modo Sistema Personal + Negocio + Second Brain
- Estructura: emprendimientos, decisiones, stakeholders, intel, metas, areas, aprendizaje, recursos
- Templates: emprendimiento, decision, meta, area, recurso, nota-rapida
- CSS snippet aplicado
- Git inicializado
