---
title: "App Android nativa FinancePY — Wave 1a (fundación: auth + Room sync engine + Dashboard + Transacciones)"
created: 2026-08-19
status: approved
---

# App Android nativa FinancePY — Wave 1a (fundación: auth + Room sync engine + Dashboard + Transacciones)

## Contexto y objetivo

El APK actual (Capacitor, WebView remoto sobre `https://finance.cd-co.com.py`, spec `2026-08-12-financespy-mobile-unificacion-capacitor-design.md`) tiene un bug de pantalla negra al abrir: diagnosticado esta sesión con `systematic-debugging` — `@capacitor/splash-screen` no está instalado (ausente de `package.json` y `node_modules/@capacitor/`), `AppTheme` no define `android:windowBackground`, y el SplashScreen API de Android 12+ oculta el splash nativo en el primer frame del WebView (vacío, no ligado a carga real de la página). Se ofrecieron 2 fixes acotados (color de fondo, o instalar+cablear el plugin de splash screen correctamente); ambos rechazados por el usuario — quiere eliminar la latencia real de red, no maquillarla: **"quiero que se procese en local... que sea como una app nativa que se procesa en el celular y no tiene la latencia de conectar con un servidor."**

Esto escaló la conversación al objetivo, ya latente en sesiones previas, de una app 100% nativa. Se presentaron 3 approaches (A: shell local con `webDir` embebido en el APK, B: profundizar el caching PWA existente, C: reescritura nativa completa). El usuario eligió **C directo**, saltando el approach puente, confirmando la escala tras advertencia explícita ("Sí, arranquemos C en serio").

**Esto reemplaza el approach de las specs `2026-08-05-financespy-android-offline-design.md` y `2026-08-12-financespy-mobile-unificacion-capacitor-design.md`** (Capacitor + WebView + IndexedDB propio + plugin nativo de Wallet). Esas specs siguen siendo la arquitectura del APK que el usuario usa **hoy y seguirá usando sin cambios durante toda la construcción de este rewrite** — ver "Estrategia de convivencia y corte" más abajo. No se tocan ni se revierten sus decisiones; se documenta la sucesión para que no queden dos specs "approved" contradictorias sin explicación.

Alcance total confirmado con el usuario (brainstorm previo, ya cerrado): **todo el paquete de una** (Dashboard, Transacciones, Presupuestos, Metas, Cuentas a Cobrar) y **todo, incluido modo negocio** (Inventario, Ventas, Pedidos, Flota). Dado el tamaño, se decidió una secuencia: **Fase 1 (finanzas personales) antes que Fase 2 (negocio/ERP)**, y Fase 1 se subdivide en waves de build:

- **1a (este spec)**: fundación — auth + motor de sync local (Room) + Dashboard + Transacciones. La porción de mayor riesgo arquitectónico; prueba el patrón completo end-to-end.
- 1b: Cuentas (solo lectura)/Reglas/Reportes — ya tienen API.
- 1c: Presupuestos/Metas/Cuentas a Cobrar — necesitan endpoints nuevos, no existen hoy.
- 1d: portar el `WalletNotificationListenerService` (Kotlin) existente + reemplazo final del APK.
- Fase 2: negocio/ERP — después de Fase 1 completa.

## Investigación técnica

Workflow de 6 agentes en paralelo (research, vía SSH directo a `fabrizio@100.105.31.71:~/financespy` — el hosting ya migró de la VM GCP a la notebook, a diferencia de cuando se escribió el spec del 2026-08-05) — 5/6 completaron, 1 (`dashboard-data-needs`) falló por un hiccup de infra ("computer went to sleep"), reintentado y confirmado directamente por mí vía SSH + `docker compose exec` antes de cerrar este spec (no se dejó sin verificar).

Hallazgos que determinan el alcance de 1a:

- **`app/models/mobile_device.rb` + Doorkeeper + `app/controllers/api/v1/*`**: stack completo y dormido, señalado ya en el spec del 2026-08-05 como "de un cliente Flutter que el equipo original nunca shippeó... si en el futuro se decide construir un cliente nativo de verdad, este stack es el punto de partida obvio, pero es una decisión aparte." **Esa decisión es este spec.** Se activa a propósito.
- **OAuth ya configurado y listo**: app Doorkeeper `"FinancePY Mobile"` ya existe (`confidential=false`, PKCE forzado — `force_pkce` en `config/initializers/doorkeeper.rb:191`), `redirect_uri = financespy://oauth/callback`, `scope = read_write`, `client_id = Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM`. Cero setup de servidor pendiente.
- **APIs reusables tal cual, sin cambios de backend**:
  - `GET/POST/PATCH/DELETE /api/v1/transactions` — CRUD completo, paginado Pagy (`page`/`per_page`), filtros ricos (`account_id(s)`, `category_id(s)`, `merchant_id(s)`, `start_date`/`end_date`, `min_amount`/`max_amount`, `tag_ids`, `type`, `search`). **Sin parámetro de delta** (`updated_since` no existe).
  - `GET /api/v1/accounts` — index/show, `balance_cents`/`cash_balance_cents`, `classification`, `account_type`, `subtype`, `status`.
  - `GET /api/v1/balance_sheet` — `net_worth`/`assets`/`liabilities` agregados (Money objects), sin desglose por cuenta.
  - `/api/v1/auth/*` — login/signup/refresh/SSO.
- **Gap real confirmado — Dashboard**: la pantalla Dashboard real (`PagesController#dashboard`) arma `@balance_sheet` + `@investment_statement` + `income_statement.income_totals/expense_totals/net_category_totals` + sankey de cashflow + donut de outflows. **Solo `balance_sheet` tiene API.** `income_statement`, `investment_statement`, sankey, donut: cero cobertura API. No se construye backend nuevo en 1a para esto — el Dashboard nativo 1a se recorta a lo que sí hay (ver Alcance).
- **`POST /api/v1/sync` NO es delta-sync.** Es un trigger fire-and-forget que encola `Family::Syncer` para refrescar conexiones bancarias externas (Plaid, SimpleFin, etc.) — no lee body, no devuelve diff, no acepta cursor de cliente. Confirmado leyendo el controller, el job y el modelo `Sync` completos. Un motor de sync real para Room tiene que construirse aparte; no hay nada que reusar acá.
- **Sin soft-delete**: `Entry`/`Transaction`/`Account` no tienen `deleted_at` ni `acts_as_paranoid`/`discard` — son hard-delete. Un filtro `updated_since` nunca vería una fila borrada. Confirmado vía grep directo sobre los 3 modelos.
- **Relación Entry↔Transaction**: `delegated_type` de Rails (no STI, no polimorfismo genérico) — `entries` es la tabla base compartida (account_id, date, name, amount, currency, parent_entry_id para splits, transfer_id para pares de transferencia, locked_attributes), `transactions` es la tabla específica (category_id, merchant_id, kind, extra jsonb). 1:1 vía `entryable_id`/`entryable_type`. El schema de Room debe espejar esta separación, no aplanarla en una sola entidad.

## Alcance (confirmado con el usuario)

- **Stack**: Kotlin Multiplatform + **Compose Multiplatform** (UI también compartida, no solo lógica — decisión explícita del usuario: "KMP para compartir código a futuro con iOS", con alcance completo incluyendo UI, no solo capa de datos). Ktor Client (networking, reemplaza Retrofit — no es multiplatform). Room KMP (DB local, driver SQLite bundled — reemplaza Room-Android-only). Koin (DI, reemplaza Hilt — no es multiplatform).
- **Auth**: OAuth2 PKCE contra la app Doorkeeper ya existente `"FinancePY Mobile"`. Sin trabajo de servidor.
- **APIs consumidas tal cual**: `accounts`, `balance_sheet`, `transactions`, `auth`. Cero endpoints nuevos en 1a.
- **Sync — MVP explícito, sin delta**: full refetch en cada sync (no `updated_since`, no tombstones de borrado — el hallazgo de que no hay soft-delete hace que un delta real requiera trabajo de backend que se pospone a propósito). Ventana de transacciones: **90 días** (usa el filtro `start_date` que ya existe en el controller). Cuentas y balance sheet: sin ventana, siempre completos (volumen bajo). Trigger: **foreground (al abrir/volver a la app) + pull-to-refresh manual**. Sin WorkManager/sync periódico en background — decisión explícita del usuario para mantener 1a simple.
- **Pantallas 1a**: Login (OAuth PKCE) → Dashboard (net worth vía `balance_sheet`, lista de cuentas, transacciones recientes — sin sankey, sin donut, sin income_statement, por el gap de API señalado arriba) → Transacciones (lista paginada, filtros básicos).
- **Room schema**: mirror del split `entries`/`transactions` del server (ver Investigación), más tabla `accounts`.
- **APK**: build de desarrollo con `applicationId` distinto (ej. `py.com.cdco.financespy.dev`) para sideload y pruebas en paralelo al APK de producción — ver siguiente sección.

Fuera de alcance explícito de 1a (YAGNI, no de todo el proyecto):

- Delta-sync real (cursor/`updated_since`) y tombstones de borrado — requieren cambios de backend (agregar el filtro + resolver el gap de hard-delete); se evalúa al hardenizar sync después de 1a, no bloquea la fundación.
- Dashboard completo (sankey, donut, income_statement, investment_statement) — sin API hoy, es trabajo de backend nuevo, no de 1a.
- Presupuestos, Metas, Cuentas a Cobrar — wave 1c, necesitan API nueva.
- Captura de notificaciones Wallet — wave 1d, sigue viviendo en el APK Capacitor actual hasta entonces (ver abajo).
- Publicación en Play Store — sigue siendo sideload.
- Cifrado at-rest de la Room DB — mismo YAGNI señalado ya en el spec del 2026-08-05 para el approach anterior; sigue siendo mejora de seguridad a evaluar aparte, no bloqueante.
- Push nativo — no es parte de 1a; se revisa cuando el resto de las waves esté más avanzado.
- El bug de la vista vacía de Cuentas a Cobrar en la web (`app/views/receivables/index.html.erb`) — hallado y diferido explícitamente por el usuario esta sesión, no relacionado a este rewrite, sigue pendiente aparte.

## Estrategia de convivencia y corte

Punto que generó confusión y se aclaró explícitamente con el usuario: **el APK Capacitor actual no se toca ni se retira durante 1a-1d.**

1. **Durante el desarrollo (1a → 1d)**: el APK nativo se compila con un `applicationId` de desarrollo distinto del de producción — Android no permite dos apps con el mismo package instaladas a la vez. Se sideloadea aparte para pruebas/dogfooding. El APK Capacitor sigue siendo el que el usuario usa día a día, sin ningún cambio, incluida la captura automática de Wallet (que ya funciona, con el logging de diagnóstico agregado esta sesión).
2. **Wallet-capture permanece en el APK viejo** durante todo este tramo — se porta recién en 1d.
3. **Corte final** (fuera de alcance de este spec, ocurre después de 1d): recién cuando 1a+1b+1c+1d estén completos y probados — paridad real de funcionalidad, incluida captura Wallet — se recompila con el `applicationId` de producción real (`py.com.cdco.financespy`) y se reemplaza el Capacitor. Un solo salto al final, consistente con la decisión previa del usuario ("Reemplaza directo", que aplica a ese momento, no a cada wave).

## Manejo de errores

- Falla de refresh de OAuth token (expiración, revocación): forzar re-login, mismo patrón PKCE de cero — no hay refresh silencioso indefinido en 1a.
- Falla de red durante full refetch: mantener los datos locales existentes en Room (última copia buena), mostrar indicador "sin conexión / última sync hace Xm" — nunca vaciar la UI ante un fetch fallido.
- Conflictos de escritura: 1a es de solo lectura desde el cliente nativo hacia estas 3 pantallas (Dashboard/Transacciones/Login) — no hay creación/edición nativa de transacciones todavía, así que no hay superficie de conflicto que resolver en esta wave. (Nota para 1c: ahí sí habrá que decidir estrategia de conflicto, cuando se agregue escritura real desde el cliente nativo.)

## Testing

- Login PKCE completo en dispositivo real: autorizar, volver a la app vía `financespy://oauth/callback`, confirmar token guardado y refresh funcionando.
- Sync manual (pull-to-refresh) y automático (foreground): confirmar que Room se actualiza sin duplicados tras refetch repetido.
- Modo avión: abrir la app sin red tras haber sincronizado antes, confirmar que Dashboard/Transacciones muestran la última copia local, no una pantalla vacía o un crash.
- Confirmar que el APK de desarrollo (`applicationId` distinto) convive instalado junto al Capacitor de producción en el mismo dispositivo, sin conflicto.

## Notas de implementación

- Orden sugerido dentro de 1a: (1) proyecto KMP base + módulo de red (Ktor + PKCE) + login funcional contra `/api/v1/auth`, (2) Room schema (`accounts`/`entries`/`transactions`) + motor de full-refetch, (3) Dashboard (consume `balance_sheet` + `accounts` + `transactions` recientes desde Room), (4) pantalla Transacciones (lista paginada desde Room, filtro básico).
- Esta es la wave de mayor riesgo arquitectónico del proyecto completo — prueba auth + Room + Ktor + Compose Multiplatform end-to-end antes de comprometerse a construir 1b/1c/1d sobre el mismo patrón.
- El hallazgo del dormant Doorkeeper/API v1 stack confirma que la superficie de servidor para 1a ya existe y está probada en producción (usada hoy por procesos internos/administrativos) — no es código sin ejercitar.
