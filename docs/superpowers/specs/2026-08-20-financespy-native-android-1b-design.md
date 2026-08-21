---
title: "App Android nativa FinancePY — Wave 1b (Cuentas detalle + Reglas CRUD acotado)"
created: 2026-08-20
status: approved
---

# App Android nativa FinancePY — Wave 1b (Cuentas detalle + Reglas CRUD acotado)

## Contexto y objetivo

Continuación directa de wave 1a (spec `2026-08-19-financespy-native-android-1a-design.md`, plan `2026-08-19-financespy-native-android-1a.md`), ya mergeada a `main` (`67c60b7` + fixes reales `d4f885e`) y **verificada en dispositivo físico real**: login OAuth PKCE, Room sync full-refetch, Dashboard y Transacciones funcionando contra producción (`https://finance.cd-co.com.py`) con datos reales de la familia.

1a dejó definida la secuencia de waves; 1b iba a ser "Cuentas (solo lectura)/Reglas/Reportes — ya tienen API", asumiendo cero trabajo de backend. La investigación de esta wave encontró que esa asunción era **parcialmente incorrecta**:

- `Api::V1::RulesController` — confirmado leyendo el código real: **solo `index`/`show`** (`config/routes.rb:476`, `resources :rules, only: [ :index, :show ]` bajo el namespace de API). No hay `create`/`update`/`destroy` — el usuario pidió explícitamente incluir crear/editar reglas en 1b, lo cual **sí requiere backend nuevo**.
- `Api::V1::RuleRunsController` — solo lectura también (historial de ejecuciones), sin cambios necesarios, se consume tal cual.
- `Rule` (modelo real, `app/models/rule.rb`) tiene un registry con **8 tipos de condición** (`TransactionName`, `TransactionAmount`, `TransactionType`, `TransactionMerchant`, `TransactionCategory`, `TransactionDetails`, `TransactionNotes`, `TransactionAccount`) y **9 tipos de acción** (`SetTransactionCategory`, `SetTransactionTags`, `SetTransactionMerchant`, `SetTransactionName`, `SetInvestmentActivityLabel`, `ExcludeTransaction`, `SetAsTransferOrPayment`, más `AutoCategorize`/`AutoDetectMerchants` si IA está habilitada). Construir un editor genérico que cubra las 8×9 combinaciones es un proyecto en sí mismo, desproporcionado para esta wave — **recortado a propósito** (ver Alcance).
- `Api::V1::CategoriesController` (`index`/`show`) y `Api::V1::TagsController`/`MerchantsController` — confirmados de solo lectura, ya alcanzan para poblar los pickers de valor que necesita el formulario de reglas (categoría, tags), sin backend nuevo para esa parte.
- "Reportes" (income_statement, cashflow sankey, outflows donut) sigue con el mismo gap de API que 1a ya documentó — nada cambió, se descarta de 1b explícitamente (decisión del usuario).

## Alcance (confirmado con el usuario)

- **Cuentas — detalle por cuenta**: tocar una cuenta en el Dashboard (o una nueva lista dedicada) abre su detalle — transacciones filtradas por `accountId` (ya en Room desde 1a, filtro simple sobre `EntryDao`), más metadata de la cuenta (institución, tipo, subtipo, `balance` vs `cash_balance`). Cero backend, cero endpoint nuevo — reusa 100% lo ya sincronizado en 1a.
- **Reglas — lectura**: lista de reglas (activas/inactivas, filtro por `resource_type`/`active` ya soportado por la API) + detalle de cada regla (condiciones y acciones tal cual las devuelve `_rule.json.jbuilder`) + historial de ejecuciones vía `rule_runs` (status, tipo de ejecución, fecha). Cero backend.
- **Reglas — crear/editar (CRUD acotado, con backend nuevo)**:
  - Formulario de creación/edición soporta **una sola condición + una sola acción por regla** (no el editor genérico de 8×9 combinaciones) — mismo patrón que el propio código Rails ya usa internamente en `Rule.create_from_grouping` (nombre de transacción + categoría).
  - Condiciones soportadas: `transaction_name` (contiene/es igual a), `transaction_merchant` (es igual a, vía picker de `merchants`), `transaction_category` (es igual a, vía picker de `categories`).
  - Acciones soportadas: `set_transaction_category` (vía picker de `categories`), `set_transaction_tags` (vía picker múltiple de `tags`).
  - **Fuera de alcance explícito de 1b** (YAGNI): `transaction_amount`/`transaction_type`/`transaction_details`/`transaction_notes`/`transaction_account` como condición; `set_transaction_merchant`/`set_transaction_name`/`set_investment_activity_label`/`exclude_transaction`/`set_as_transfer_or_payment`/`auto_categorize`/`auto_detect_merchants` como acción; condiciones compuestas (AND/OR de múltiples condiciones — el modelo ya prohíbe compound conditions anidadas, `no_nested_compound_conditions`, así que ni siquiera el propio Rails lo soporta hoy); ejecutar una regla manualmente desde la app (¿correr contra el histórico ya sincronizado? no está en el alcance de esta wave).
  - Activar/desactivar (`active` toggle) y borrar una regla existente sí entran, son mutaciones triviales sobre el modelo ya existente.
- **Reportes**: **fuera de 1b por completo** (decisión explícita del usuario) — no se construye ninguna pantalla ni se toca el gap de API. Se retoma el día que se decida construir esa API real.

## Trabajo de backend requerido (nuevo respecto a 1a)

Todo en `Api::V1::RulesController` (Rails, en el repo real, fuera de `native/financespy-kmp/`):

- `create`: acepta `resource_type` (fijo `"transaction"` para 1b), `name` opcional, `active` (boolean), `conditions_attributes` (array de 1 elemento: `condition_type`, `operator`, `value`), `actions_attributes` (array de 1 elemento: `action_type`, `value`) — usa `accepts_nested_attributes_for` que el modelo ya expone, el controller solo necesita permitir esos params y llamar `family.rules.create`.
- `update`: mismo shape, sobre `family.rules.find(params[:id]).update`.
- `destroy`: `family.rules.find(params[:id]).destroy` (el modelo ya tiene `dependent: :destroy` en conditions/actions/rule_runs).
- Vistas jbuilder `create.json.jbuilder`/`update.json.jbuilder` (pueden reusar `_rule` parcial existente) — `destroy` sin vista, 204 o mensaje simple.
- Rutas: cambiar `resources :rules, only: [ :index, :show ]` (línea 476 de `config/routes.rb`) a incluir `:create, :update, :destroy` — **no** agregar `except: :show` como tiene el bloque web (línea 394, que es un recurso Rails distinto para las vistas Turbo, no tocar ese).

## Arquitectura nativa (KMP)

Mismo patrón ya probado en 1a — nada nuevo a nivel de stack:

- **Room**: nuevas entities `RuleEntity` (id, name, resourceType, active, conditionType, conditionOperator, conditionValue, actionType, actionValue — aplanado en una sola tabla dado que 1b solo soporta 1 condición + 1 acción por regla, evita modelar la relación 1-a-muchos completa que el server sí tiene) y `RuleRunEntity` (id, ruleId, status, executionType, executedAt). Mirror simplificado a propósito del modelo real del server — si una wave futura necesita reglas multi-condición, ahí se revisita el aplanado.
- **DTOs**: `RuleDto`/`RuleRunDto`, más `CategoryDto`/`MerchantDto`/`TagDto` (nuevos, para los pickers — no existían en 1a).
- **Sync**: reglas se sincronizan igual que cuentas/transacciones (full-refetch, parte del mismo `SyncEngine.syncAll()` — no tiene ventana de fecha como transacciones, se trae todo). Categorías/merchants/tags se piden on-demand al abrir el formulario de creación (no se cachean en Room — son catálogos que cambian poco y el usuario los ve una vez por sesión de creación de regla, no ganancia real de cachearlos en 1b).
- **Mutaciones** (crear/editar/borrar regla, toggle active): van directo a la API (no pasan por Room primero) — a diferencia del resto de 1a que es puramente de lectura, esta es la primera escritura real del cliente nativo. Tras una mutación exitosa, se dispara un refresh puntual de `RuleDao` (no hace falta re-sincronizar todo `SyncEngine.syncAll()`, sería desproporcionado para guardar 1 regla).
- **Pantallas**: `AccountDetailScreen` (nueva), `RulesListScreen` (nueva), `RuleDetailScreen` (nueva, incluye historial de `RuleRuns`), `RuleFormScreen` (nueva, create y edit comparten el mismo composable). Navegación: se agrega una tab más al `TabRow` existente (Dashboard/Transacciones/Reglas) — Cuentas-detalle no es una tab nueva, es una pantalla a la que se navega tocando una cuenta desde Dashboard (necesita introducir navegación real, hoy 1a solo tiene tabs planos sin stack — se evalúa `Navigation Compose` multiplatform para esto, sin overengineer: alcanza con un `NavHost` simple de 2-3 destinos).

## Manejo de errores

- Formulario de regla: validación mínima client-side (condición y acción no pueden estar vacías) antes de mandar al server — el server igual valida (`min_actions`, `no_duplicate_actions`), la app debe mostrar el mensaje de error real que devuelva la API si la validación server-side falla, no inventar un mensaje genérico.
- Borrar/activar-desactivar: mutación optimista simple (deshabilitar el control mientras la request está en vuelo), sin necesidad de rollback complejo dado el volumen bajo esperado de reglas por familia.
- Mismo patrón ya validado en 1a para fallos de red: mostrar el último estado bueno conocido en Room, nunca vaciar la pantalla ante un fetch fallido.

## Testing

- Mismo patrón que 1a: build real (`./gradlew :androidApp:assembleDebug`) + **instalación y prueba en dispositivo físico real antes de dar por cerrada la wave** — 1a demostró que un build exitoso no garantiza que la app abra ni funcione (5 bugs reales solo visibles en runtime, documentados en el commit `d4f885e`). No repetir ese error: cada pantalla nueva se prueba tocándola en el teléfono, no solo compilando.
- Crear una regla real de prueba (ej. "Uber" en `transaction_name` → categoría "Transporte"), confirmar que aparece en el listado, confirmar en la web real (`finance.cd-co.com.py/rules`) que la regla existe y tiene el shape esperado — cierre del círculo cliente-nativo → servidor real.
- Editar y borrar esa misma regla de prueba antes de terminar, para no dejar basura de testing en los datos reales de la familia.

## Notas de implementación

- Orden sugerido: (1) backend Rails (create/update/destroy en `RulesController` + rutas + vistas), (2) Room entities + DTOs + sync de reglas/rule_runs, (3) `AccountDetailScreen` (la pieza sin backend, más simple, prueba el patrón de navegación), (4) `RulesListScreen` + `RuleDetailScreen` (lectura), (5) `RuleFormScreen` (escritura, la pieza más compleja, depende de que (1)-(4) ya estén probados).
- El backend (1) es Rails puro, en el repo real fuera de `native/financespy-kmp/` — mismo repo (`fabriziocorbeta/cd-co-erp`), pero un commit/PR conceptualmente distinto del resto de 1b (código nativo). Se mantienen separados para que una revisión de PR pueda evaluar cada uno con su propio criterio (seguridad del endpoint nuevo vs. corrección del cliente).
- Este spec asume que la infraestructura de auth/sync/Room de 1a sigue funcionando tal cual quedó verificada — no se re-valida desde cero, se construye encima.
