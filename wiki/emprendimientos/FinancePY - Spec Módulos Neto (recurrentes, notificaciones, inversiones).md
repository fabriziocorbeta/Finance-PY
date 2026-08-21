---
type: emprendimiento
title: "FinancePY - Spec Módulos Neto (recurrentes, notificaciones, inversiones)"
status: auditado contra código real — reporte fuente mayormente redundante; automatización de notificaciones bloqueada en decisión de plataforma (nativo vs. tercero)
created: 2026-08-08
updated: 2026-08-10
tags: [emprendimiento, financepy, spec, premium, pro]
---

# FinancePY — Spec módulos inspirados en app "Neto"

Análisis de reporte Gemini (2026-08-08) con ideas de features nuevas para FinancePY, inspiradas en la app "Neto". Fabrizio pidió: documentar en vault + versionar en git. Este doc es **spec, no implementación** — nada de esto tocó código todavía.

## Contexto

Reporte propone 3 módulos Pro + rediseño de Ajustes:
1. Automatización lectura gastos (Google Wallet, notificaciones Android) — offline-first
2. Transacciones recurrentes (nómina, alquiler, suscripciones)
3. Portfolio tracker (cripto, acciones, ETFs, fondos)
4. Rediseño menú Ajustes (perfil, privacidad, biométrico, exportar/importar, cuenta)

Relación con [[FinancePY - Módulos Premium ERP]]: ese doc trata los 4 módulos ERP (inventario/ventas/pedidos/flota) portados del [[Agente IA CD & Co.|CD & Co ERP]]. Este doc es un track **separado e independiente** — features consumer-fintech tipo Neto, no ERP. Ambos comparten el patrón "premium/Pro gate", pero no comparten código ni modelos.

## El módulo 1 NO es feature nueva — es un bug de algo ya construido

**Contexto que el reporte de Gemini no tenía** (aportado por Fabrizio 2026-08-08): la detección de notificaciones **ya se intentó y no funcionó**. El reporte de Gemini es una re-especificación posterior a ese fracaso, no un punto de partida. Tratarlo como greenfield lleva a reconstruir lo que ya existe en vez de arreglar lo roto.

### Lo que realmente está construido

Spec original: `docs/superpowers/specs/2026-07-28-android-purchase-webhook-design.md`. La arquitectura **nunca dependió de que la app leyera notificaciones**:

```
Google Wallet → Tasker/MacroDroid lee (NotificationListenerService)
              → parsea importe/comercio con su propio regex
              → POST /webhooks/android_purchase (Bearer token)
              → Rails crea Entry
```

Tasker tiene el permiso de lectura de notificaciones, no FinancePY. Diseño correcto: esquiva por completo la limitación del empaquetado.

**Lado Rails: completo y en producción.** Verificado en código real:
- `app/controllers/webhooks_controller.rb:60` — acción `android_purchase`
- `app/models/android_purchase/webhook_processor.rb` — idempotencia por `SHA256(amount|timestamp|merchant)`, scoping por family, manejo de `RecordNotUnique` para reintentos de Tasker
- `config/routes.rb:596` — `post "android_purchase"`
- `compose.prod.yml:26-27` — `ANDROID_WEBHOOK_TOKEN` / `ANDROID_WEBHOOK_FAMILY_ID`
- `test/models/android_purchase/` — tests existen
- Commits: `e384770`, `3ab4149`, `ed09057`, `275a277`, `e70fb33`

### Corrección: el shell es TWA, no Capacitor

El spec del 2026-08-05 eligió Capacitor, pero **lo que se buildeó el 2026-08-06/07 fue un TWA puro con Bubblewrap** (`~/code/financespy-twa`, `generatorApp: bubblewrap-cli`, APK firmada, `packageId: py.com.cd_co.finance.twa`). El `AndroidManifest.xml` generado declara `POST_NOTIFICATIONS` y un `DelegationService` para Web Push — o sea, **mostrar** notificaciones. Cero `BIND_NOTIFICATION_LISTENER_SERVICE`.

Trampa de nombre a tener presente: `"enableNotifications": true` en `twa-manifest.json` habilita *mostrar* notificaciones web push. **No** habilita leerlas. Son operaciones inversas y es una confusión fácil.

Un TWA no puede leer notificaciones ajenas bajo ninguna configuración — es Chrome renderizando el sitio, sin puente JS↔nativo. Pero eso **no bloquea nada**, porque el diseño real delega la lectura a Tasker.

### Sospechoso principal del fallo: formato numérico paraguayo

`webhook_processor.rb` parsea el importe con `BigDecimal(@amount.to_s)`:

```ruby
BigDecimal("150.000")   # => 150.0   ← NO 150000
```

En Paraguay el formato es `₲ 150.000` (punto = separador de miles). Si Tasker manda `150.000`, Rails responde **200 OK** y guarda ₲150 en vez de ₲150.000 — mil veces menos, sin error ni log. Falla silenciosa, encaja perfecto con un "no funcionó" sin diagnóstico claro.

Si manda con el símbolo (`₲ 150.000`), `BigDecimal` tira `ArgumentError` → `nil` → 422 `"amount is required and must be numeric"`. Ese es ruidoso y fácil de ver.

### Tabla de diagnóstico por código HTTP

| Código | Significa | Dónde está el problema |
|---|---|---|
| sin requests en el log | Tasker nunca disparó | teléfono: permiso de acceso a notificaciones, perfil de Tasker, filtro de app |
| 503 | `ANDROID_WEBHOOK_TOKEN` vacío | `.env` del server |
| 401 | token no coincide | Tasker |
| 422 `Unknown account_id` | UUID de cuenta mal o `FAMILY_ID` no coincide | Tasker / `.env` |
| 422 `amount...numeric` | regex trae símbolo o formato raro | regex de Tasker |
| **200 con monto 1000× menor** | **bug de separador de miles** | `numeric_amount` + regex |

Primer paso al retomar: ver si llegan requests (comando en la sección de próximos pasos).

**Nada de esto está verificado contra el teléfono todavía** — solo contra el código del server. Ver [[Verificar antes de arreglar]].

## Auditoría contra el código real (2026-08-08)

Auditoría con agentes paralelos sobre `~/code/financespy` (rama `main`), con verificación adversarial. **Veredicto: el reporte de Gemini propone construir lo que ya está construido.** De las funcionalidades que lista, ~40 ya existen con modelo + UI + tests. Gemini no tenía acceso al código; escribió sobre la app "Neto", no sobre FinancePY.

Las propuestas de schema que yo mismo había redactado en la primera versión de este doc (`recurring_transactions`, `holdings`, `asset_quotes`, `captured_notifications`) **quedan descartadas por redundantes**. Se conservan abajo solo los faltantes reales.

### Módulo 2 — Recurrentes: existe casi completo

| Pide Gemini | Estado real |
|---|---|
| Crear movimientos que se repiten | `recurring_transaction.rb:1-324`, tabla `db/schema.rb:1277-1301` |
| Detectar suscripciones (Spotify, Netflix) | **Detección automática de patrones** — `recurring_transaction/identifier.rb:10-141`: agrupa 3 meses de entries, exige ≥3 ocurrencias, clustering de días con distancia circular y std_dev ≤ 5 |
| Alertas en dashboard de próximo pago | Tab "Upcoming" en `/transactions` — `transactions_controller.rb:57-64`, avisa próximos 10 días con badge "Projected" |
| Gestión | Pantalla en Ajustes: `recurring_transactions_controller.rb`, pausar/reanudar/borrar, API REST v1 completa |

**Faltantes reales:**
- **Solo frecuencia mensual.** No hay columna `frequency` ni `interval`; `calculate_next_expected_date` hace siempre `from_date.next_month`. Un Netflix semanal o un seguro anual no se modelan. Esfuerzo medio: columna nueva + generalizar el clustering del Identifier.
- **Sin fecha de fin.** No existe `end_date`. Una cuota de 12 meses se proyecta para siempre hasta que la limpieza la marque inactiva por inactividad.
- **Las ocurrencias no se materializan.** `projected_entry` devuelve un `OpenStruct` en memoria, nunca crea un `Entry`. Para "avisame antes de que se cobre" alcanza; para "reservá el dinero", no.

### Módulo 3 — Inversiones: existe completo, incluso cripto

Modelos `investment.rb`, `holding.rb`, `security.rb`, `trade.rb`, `trade_import.rb`. Cripto soportada (`Security#crypto?`, `security.rb:65-73`). Providers de cotizaciones ya integrados: `binance`, `coinbase`, `coinstats`, `alpha_vantage`, `tiingo`, `twelve_data`, `eodhd`, `yahoo_finance`, `mfapi`, `snaptrade`, `indexa_capital`.

No hace falta elegir proveedor de cotizaciones ni diseñar `asset_quotes` — ya está. Lo único que no existe es la "tarjeta visual compartible" del patrimonio, que es cosmética.

### Módulo 4 — Ajustes: 6 de 8 ítems ya existen

| Pide Gemini | Estado real |
|---|---|
| Tema auto/claro/oscuro | Existe — `settings/appearances_controller.rb`, `users.theme` default `"system"` |
| Moneda principal | Existe (`families.currency`), **pero en Ajustes se muestra read-only** — el único selector está en el onboarding |
| Idioma | Existe (`users.locale`) |
| Presupuestos | Existe completo (ver abajo) |
| Categorías ABM | Existe completo, **ya está en Ajustes** (`_settings_nav.html.erb:18`) |
| Metas de ahorro | Existe completo con huchas virtuales reales |
| **Ocultar saldos** | **Existe punta a punta** — `privacy_mode_controller.js`, 143 elementos marcados `.privacy-sensitive` en 30+ vistas, anti-flash en `<head>`. Usa blur CSS, no asteriscos |
| Exportar/importar datos | Existe — `family/data_exporter.rb`, `family/data_importer.rb`, imports con mapeo de columnas |
| Eliminar cuenta | Existe — `users_controller.rb:59`, `settings/profiles_controller.rb:14` |
| **Bloqueo biométrico** | **NO existe.** Hay WebAuthn/TOTP como 2FA de *login*, que no es lo mismo que bloquear la app al abrirla |
| **Control de notificaciones** | **NO existe** ningún sistema de notificaciones: sin tabla, sin modelo, sin mailer de alertas |
| Restaurar compras | NO existe (sin StoreKit/Play Billing) |

### Presupuestos y metas: existen, y hay un bug real

Presupuestos mensuales con límite por categoría, jerarquía padre/hijo, copiar mes anterior. Categorías con color, icono, jerarquía y borrado con reasignación. Metas con máquina de estados, `goal_accounts` (earmark de saldo real) y `goal_pledges`.

**Bug encontrado de paso, más valioso que cualquier feature del reporte:** `GoalPledge::Reconciler` sabe casar pledges contra transacciones, pero solo se invoca desde `Account::ReconciliationManager:17` (valuations). No hay hook en `Entry` ni en `Transaction`. Resultado: los pledges de tipo `transfer` — el default para cuentas conectadas — **nunca pasan a `matched`**. Y nada llama a `expire!`, así que los vencidos quedan `open` para siempre. Esto es reparación, no módulo nuevo.

### Suscripción Pro: el hallazgo que más importa para comercializar

Stripe está integrado de punta a punta y funciona: checkout, portal de facturación, webhook firmado, trial de 45 días, tests con cassettes VCR. `FeatureGuardable` y `RequireBusinessMode` ya bloquean cinco controllers.

Tres problemas de fondo para vender esto en Paraguay:

1. **Stripe no opera con entidades paraguayas.** Y el acoplamiento es por nombre: `families.stripe_customer_id`, `subscriptions.stripe_id`, y `can_manage_subscription?` depende de que exista `stripe_customer_id` — una familia con cobro local no vería el panel de plan. Falta un provider local (Bancard, PagoPar, Tigo Money): cero coincidencias en el código. **Esfuerzo alto, y es el bloqueante comercial real.**
2. **El gating es binario, no por tier.** No hay columna `plan`/`tier`; "plan" solo significa mensual vs anual. Todo el reporte asume un modelo free/Pro que no existe. La buena noticia: el mecanismo de gating ya está probado, falta enchufarle la condición de plan (esfuerzo medio).
3. **El flujo está escrito como donación voluntaria al upstream, no como plan comercial.** Flashes hardcodeados en inglés nombrando al upstream (`subscriptions_controller.rb:36,57`), locales `es.yml` con el nombre del upstream, botón "Contribuir y apoyar". Deuda de branding directamente incompatible con comercializar.

### Dos bugs de i18n que afectan a usuarios paraguayos hoy

- **`es-PY` existe pero es inalcanzable.** El archivo de locale ya tiene IVA 10/5/exento y bancos paraguayos (Itaú, Continental, Visión, GNB, BCP), pero `es-PY` no está en `SUPPORTED_LOCALES` y `language_options` filtra por esa constante. El usuario nunca puede elegirlo. **Fix de un renglón** en `languages_helper.rb:157-170`.
- **Fallback de i18n roto.** `config/application.rb:28-29` pone `config.i18n.fallbacks = true` con `default_locale :es`. Rails cae al `default_locale`, o sea a `:es` — una clave faltante en `es.yml` **no cae a inglés, muestra "translation missing"**. Faltan `es.yml` completos en ~9 áreas. Verificar en runtime antes de asumir.

## Schema propuesto originalmente — DESCARTADO

> Lo de abajo fue la primera propuesta, escrita antes de auditar el código. Se conserva solo como registro de qué se descartó y por qué. **No implementar.** `recurring_transactions` y `holdings` ya existen con más funcionalidad que lo propuesto acá.

<details>
<summary>Ver propuesta descartada</summary>

### Transacciones recurrentes

```ruby
create_table :recurring_transactions, id: :uuid do |t|
  t.references :family, null: false, foreign_key: true, type: :uuid
  t.references :account, null: false, foreign_key: true, type: :uuid
  t.references :category, foreign_key: true, type: :uuid
  t.string   :name, null: false                    # "Netflix", "Alquiler"
  t.decimal  :amount, precision: 19, scale: 4, null: false
  t.string   :currency, null: false
  t.string   :kind, null: false                     # income / expense
  t.string   :frequency, null: false                # weekly / monthly / yearly
  t.integer  :interval, default: 1, null: false      # cada N unidades de frequency
  t.date     :next_occurrence_on, null: false
  t.date     :ends_on                                # null = indefinido
  t.boolean  :active, default: true, null: false
  t.timestamps
end
add_index :recurring_transactions, [:family_id, :active, :next_occurrence_on]
```

```ruby
create_table :recurring_transaction_occurrences, id: :uuid do |t|
  t.references :recurring_transaction, null: false, foreign_key: true, type: :uuid
  t.references :transaction, foreign_key: true, type: :uuid  # null hasta materializarse
  t.date     :due_on, null: false
  t.string   :status, default: "pending", null: false  # pending / posted / skipped
  t.timestamps
end
```

Job diario (`RecurringTransactions::GenerateOccurrencesJob`) recorre `recurring_transactions` con `next_occurrence_on <= Date.current`, crea `Transaction` real + `Occurrence`, avanza `next_occurrence_on` según `frequency`/`interval`. Dashboard lee `occurrences` con `due_on` próximo para las alertas visuales — no consulta `recurring_transactions` directo, evita recalcular fechas en vista.

### Portfolio / inversiones

Evaluar primero si el proyecto upstream ya trae `Investment`/`Security`/`Holding` (el upstream suele traer esto para brokerage accounts) — si existe, extender en vez de crear desde cero.

```ruby
create_table :holdings, id: :uuid do |t|
  t.references :family, null: false, foreign_key: true, type: :uuid
  t.string   :asset_type, null: false   # crypto / stock / etf / fund
  t.string   :symbol, null: false        # BTC, AAPL, VOO
  t.decimal  :quantity, precision: 20, scale: 8, null: false
  t.decimal  :avg_cost, precision: 19, scale: 4
  t.string   :cost_currency
  t.timestamps
end
```

```ruby
create_table :asset_quotes, id: :uuid do |t|
  t.string   :symbol, null: false
  t.string   :asset_type, null: false
  t.decimal  :price, precision: 19, scale: 8, null: false
  t.string   :currency, null: false
  t.datetime :fetched_at, null: false
end
add_index :asset_quotes, [:symbol, :fetched_at]
```

`asset_quotes` es cache poblado por job periódico contra API externa de mercado (a definir: CoinGecko para cripto, Alpha Vantage/Finnhub para acciones/ETF) — nunca fetch síncrono en el request del dashboard. Patrimonio total = `Σ holding.quantity × última cotización` convertido a moneda base de la family, mismo patrón de conversión que ya usa `Balance::Materializer` para cuentas normales.

</details>

### Módulo notificaciones — el schema propuesto por Gemini es redundante

Gemini propone tablas `notification_capture_settings` y `captured_notifications` con `client_uuid` para dedup offline. **No hacen falta**: eso ya está resuelto en producción con otro diseño, más simple y ya probado.

Lo que existe hoy:
- **Dedup**: `external_id = SHA256("#{amount}|#{timestamp}|#{merchant}")` sobre `entries`, con índice único `index_entries_on_account_source_and_external_id`. Cubre el caso de reintento de Tasker tras corte de red — el mismo que `client_uuid` iba a resolver.
- **Payload crudo**: se guarda en `Transaction#extra` (`raw_text`, `source`, `item`), no en tabla aparte.
- **Cuenta destino**: `account_id` lo manda Tasker en el POST; el scoping de seguridad lo da `ANDROID_WEBHOOK_FAMILY_ID`.
- **Origen**: `entries.source = "google_play"`.

Crear las tablas de Gemini sería duplicar un mecanismo de idempotencia que ya funciona y ya tiene tests. Si en algún momento se quiere multi-usuario de verdad (hoy es single-user, single-phone, single-token), ahí sí conviene revisar el diseño — pero como evolución de lo existente, no como tabla nueva paralela.

## Flujo de permisos — no aplica como lo plantea Gemini

Gemini describe pedir el permiso de notificaciones *dentro de FinancePY* (toggle en Ajustes → `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` → `NotificationListenerService` propio). **Eso no es posible en el empaquetado actual y tampoco es necesario.**

El permiso vive en **Tasker/MacroDroid**, que ya es una app nativa con acceso a notificaciones concedido por el usuario una sola vez. FinancePY nunca ve una notificación — solo recibe un POST ya parseado. La UI de FinancePY no tiene ningún rol en el flujo de permisos.

Lo único que sí vale rescatar del planteo de Gemini es la **herramienta de diagnóstico**: hoy no hay forma desde la app de saber si el webhook está recibiendo algo. Un endpoint o vista que muestre los últimos POST recibidos (con status y payload crudo) resolvería exactamente el problema de "no funcionó y no sé en qué eslabón". Eso sí es un faltante real y barato.

## Próximos pasos

**Primero diagnosticar, después construir.** Orden importa:

- [ ] **Ver si llegan requests al webhook** — desde WSL en la notebook (la VM GCP está apagada desde la migración del 2026-08-08):
      `cd ~/financespy && docker compose -f compose.local.yml logs web --since 168h | grep -i android_purchase`
- [ ] Según el código HTTP que aparezca, usar la tabla de diagnóstico de arriba para ubicar el eslabón roto
- [ ] Revisar el regex de Tasker contra el formato real de la notificación de Wallet en guaraníes — sospecha principal: separador de miles (`150.000` → `BigDecimal` da 150.0)
- [ ] Si se confirma: normalizar el importe en `webhook_processor.rb` (quitar puntos de miles antes de `BigDecimal`) **y** agregar validación de rango que rechace montos absurdamente bajos en vez de aceptarlos en silencio
- [ ] Agregar la vista de diagnóstico de últimos webhooks recibidos (faltante real)
### Backlog real, ordenado por relación valor/esfuerzo

Nada de esto sale del reporte de Gemini — sale de auditar el código. Ordenado de más barato y valioso a más caro:

1. **`es-PY` inalcanzable** — agregar a `SUPPORTED_LOCALES` en `languages_helper.rb:157-170`. Un renglón, y desbloquea el locale con IVA y bancos paraguayos que ya está escrito.
2. **Bug de pledges huérfanos** — `GoalPledge::Reconciler` no se dispara con transacciones; los pledges `transfer` nunca se marcan `matched`. Agregar el hook + un job que llame `expire!`. Esfuerzo bajo, arregla un módulo que hoy miente al usuario.
3. **Verificar el fallback de i18n en runtime** — `fallbacks = true` con `default_locale :es` no protege de nada. Buscar "translation missing" en las pantallas de las ~9 áreas sin `es.yml`.
4. **Toggle de "ocultar saldos" en Ajustes + persistirlo** — hoy vive solo en `localStorage`, no sincroniza entre dispositivos. Colgarlo de `users.preferences` (mecanismo jsonb ya existe).
5. **Selector de moneda base en Ajustes** — el `permit` ya está (`users_controller.rb:109`), falta el `select` en la vista. Decidir qué pasa con los importes históricos.
6. **Frecuencias de recurrentes distintas a mensual** — columna `frequency`/`interval` + generalizar `calculate_next_expected_date` y el clustering del Identifier. Esfuerzo medio, alto valor para "Netflix semanal / seguro anual".
7. **Gating por tier (free vs Pro)** — el mecanismo (`FeatureGuardable`) ya está probado en 5 controllers; falta la columna `plan` y enchufar la condición. Esfuerzo medio.
8. **Limpiar el branding de donación al upstream** — flashes hardcodeados, locales `es.yml`, botón "Contribuir y apoyar". Bloqueante para comercializar, esfuerzo bajo-medio.
9. **Sistema de notificaciones** — no existe nada. Es prerequisito de las alertas de presupuesto excedido y de los avisos de recurrentes por push. Esfuerzo alto.
10. **Provider de pagos local (Bancard / PagoPar / Tigo Money)** — **el bloqueante comercial real.** Stripe no opera con entidades paraguayas y el código está acoplado a Stripe por nombre de columna. Esfuerzo alto, decisión de negocio antes que técnica.
11. **Bloqueo biométrico al abrir la app** — no existe; requiere el shell nativo. Con TWA no es posible.

### Cobertura de la auditoría

7 áreas planificadas, **4 completaron** con verificación adversarial (recurrentes, gating Pro, preferencias, presupuestos/metas). 3 agentes se colgaron por timeout (inversiones, export/import, notificaciones Android) — inversiones y export/import se verificaron después a mano y quedaron cubiertas arriba; notificaciones Android está cubierta por el análisis manual de la sección de diagnóstico. Los refutadores de `recurrentes` y `presupuestos_metas` fallaron por error de conexión, así que **esas dos áreas no tienen verificación adversarial** — tratar sus hallazgos con algo menos de confianza que los de `pro_gating` y `preferencias`, que sí fueron refutados (veredicto PARCIAL en ambos).

**Restricción de recursos a tener en cuenta**: el server ahora corre en una notebook ASUS i5 7ma gen / 8 GB RAM bajo WSL2, con ~3,1 GB ya usados por los 4 contenedores y margen ajustado. Cualquier módulo que agregue jobs periódicos (cotizaciones de mercado del portfolio, generación de recurrentes) suma carga sostenida en una máquina que ya está justa. Dimensionar antes de activar, no después.

## Sesión 2026-08-08/10 — diagnóstico completo del webhook + decisión de plataforma pendiente

### 1. Bug real encontrado y arreglado en producción (dos rondas)

El webhook Android→FinancePY (spec 2026-07-28) estaba completo en Rails desde antes, pero nunca funcionó en la práctica. Causas encontradas y resueltas, en orden:

- **Commit `5b1daba`**: `BigDecimal` mal-parseaba montos con separador de miles hipotético (`"150.000"` → `150.0`, no confirmado contra una notificación real).
- **503 persistente tras migrar VM→notebook**: `ANDROID_WEBHOOK_TOKEN` nunca se copió a `.env.local` en la migración. Confirmado con `curl` manual → 503 "Android webhook not configured". Arreglado seteando el token en `.env.local` y recreando el contenedor.
- **Commit `f20fa8d`**: con una notificación real capturada (`"PYG112,000 con GNB GOOGLE ••6536"`), se confirmó que el formato real es **coma como separador de miles, sin decimales** — el fix anterior (`5b1daba`) en realidad **corrompía este caso real** (`112,000` → `112.0`, el mismo bug 1000x que se quería evitar, con un separador distinto al asumido). Corregido: la rama de coma-decimal ahora exige al menos un grupo de puntos antes de la coma para no confundirse con miles-por-coma.

Ambos commits: suite completo (3706-3710 tests) + rubocop verdes localmente antes de pushear. Ver `app/models/android_purchase/webhook_processor.rb` y su test.

### 2. Mapeo de cuentas confirmado

4 tarjetas en Google Wallet, mapeadas a cuentas reales de FinancePY (Familia Corbeta):

| Tarjeta Wallet | Cuenta FinancePY | account_id |
|---|---|---|
| Mastercard-Ueno / "UENO GPAY" | Mastercard - Ueno | `74fa6687-bbf7-45d2-aa71-f06bca3b2013` |
| Amex Gold | Amex - Glod | `d47f5223-a988-46f5-9bc5-beefc4c7fefd` |
| Mastercard-Conti / "MASTERCARD CLASICA" | Mastercard - Conti | `952d06b3-f915-4cf1-b4c2-952fb131f2be` |
| MasterCard-GNB / "GNB GOOGLE" | MasterCard - GNB (creada en esta sesión) | `43d84b14-b3be-44a9-be37-7ec1ae4661f2` |

Nota: se creó por error una cuenta "MasterCard - GNB" duplicada (`b23c3a99-6fca-4924-932e-23520e78c38a`), ya eliminada por Fabrizio.

### 3. Bloqueante actual: no hay forma nativa de Android/Samsung de leer texto de notificaciones y mandarlo por HTTP

Fabrizio pidió explícitamente una solución **100% nativa del sistema operativo**, sin apps de terceros (nada de Tasker/MacroDroid). Se investigó a fondo el catálogo real de "Modos y Rutinas" de Samsung (capturas de pantalla reales del dispositivo, no documentación genérica):

- **Trigger "Notificación recibida"**: existe, permite filtrar por app + palabra clave (`Cuando se encuentran todas` / `Cuando se encuentra alguna`). **Es un filtro booleano — no expone el texto de la notificación como variable reutilizable** en ningún paso posterior.
- **Catálogo de acciones ("Entonces")**: confirmado contra múltiples fuentes (Xataka, Samsung Community, Samsung support) — solo toggles de sistema (No Molestar, brillo, modo oscuro, sonido, conectividad, abrir apps). **Ninguna acción de red, HTTP request o webhook.**

Conclusión técnica: **no existe combinación de configuración nativa que resuelva esto.** No es una limitación de este teléfono en particular — ningún fabricante Android (Samsung, Pixel/stock) expone esto de fábrica. Confirmado también que MacroDroid (alternativa gratis a Tasker, ya contemplada en el spec original 2026-07-28) sí tiene todo lo necesario: `Action: HTTP Request` soporta POST + headers custom (`Authorization: Bearer`) + body JSON, sin restricción de versión Pro para esa acción específica — ver [MacroDroid Wiki](https://www.macrodroidforum.com/wiki/index.php/Action:_HTTP_Request). El límite gratuito es 5 macros; esta automatización usa 1 solo macro.

### 4. Opciones reales sobre la mesa (sin tercera vía nativa oculta)

1. **MacroDroid** (gratis, ~5 min) — trigger Notificación (Wallet) → `Variable Search Replace` con regex captura monto+tarjeta → `If/ElseIf` mapea tarjeta→`account_id` → `HTTP Request` POST al webhook. Diseño completo ya armado (extracción regex `PYG([\d,]+) con (.+)`, mapeo de las 4 cuentas, Flash de verificación antes del POST real) — pendiente de ejecutar en el teléfono.
2. **App Android nativa propia** (Kotlin, `NotificationListenerService`) — cero dependencia de terceros, pero es desarrollo real (Android Studio, firmar APK, mismo tipo de esfuerzo que `financespy-twa`). Sin diseño técnico armado todavía.
3. **Sin automatización** — carga manual de gastos de Google Pay en FinancePY.

Fabrizio va a investigar por su cuenta antes de decidir. Sin decisión tomada al cierre de esta sesión.

## Referencias

- Reporte fuente: Gemini, 2026-08-08 (pegado por Fabrizio en conversación, no archivado como fuente — solo el análisis queda en este doc)
- [[FinancePY - Módulos Premium ERP]] — track paralelo de features ERP
- [[financespy]] — estado general del proyecto
- [[Verificar antes de arreglar]]
- `docs/superpowers/specs/2026-07-28-android-purchase-webhook-design.md` — **el spec que importa para el módulo 1**: arquitectura Tasker → webhook, ya implementada
- `docs/superpowers/specs/2026-08-05-financespy-android-offline-design.md` — eligió Capacitor, pero lo buildeado fue TWA Bubblewrap; leer con esa salvedad
- [[FinancePY — APK Android (TWA) con Bubblewrap)]] — el empaquetado que realmente existe
- [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]] — hosting actual (notebook ASUS, VM GCP apagada)
- `docs/superpowers/plans/2026-08-05-financespy-android-offline-phase1.md` — plan Fase 1 (shippeada), roadmap Fases 2-3
