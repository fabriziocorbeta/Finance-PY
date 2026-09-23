# Inventario RLS -- 114 tablas de FinancePY
Ola 2 / E1 Etapa A. Generado inspeccionando `db/structure.sql` (114 `CREATE TABLE public.*`, 23 `CREATE POLICY ..._family_isolation_policy`, 23 `FORCE ROW LEVEL SECURITY`), `app/models/**/*.rb` (asociaciones `belongs_to`/`delegated_type`/`as: :polymorphic`), `app/models/concerns/rls_context.rb`, `app/jobs/concerns/active_job_row_level_security.rb`, `app/controllers/concerns/{authentication,row_level_security}.rb`, `app/controllers/api/v1/base_controller.rb`, `app/controllers/webhooks_controller.rb`, `config/schedule.yml` y los jobs que lista.
No se cambio comportamiento en esta etapa -- solo lectura/documentacion.

## Resumen
- **114/114 tablas** de `db/structure.sql` cubiertas.
- **23 tablas** tienen `CREATE POLICY ..._family_isolation_policy` (todas ellas tambien con `FORCE ROW LEVEL SECURITY`, 23 tablas -- el contexto comun decia 24, el conteo real contra `db/structure.sql` da **23**; ver nota abajo).
- **91 tablas** no tienen ninguna forma de RLS (`ENABLE`/`FORCE`/`POLICY` ausentes).
- Clasificacion:
  - `root`: 1
  - `direct`: 35
  - `direct-nullable`: 1
  - `indirect`: 48
  - `auth`: 14
  - `global`: 12
  - `storage`: 3

### Correccion a una premisa del contexto comun
El contexto comun lista 24 tablas con FORCE (incluye `categories` y `tags` en la enumeracion). Verificado contra `db/structure.sql`: hay exactamente **23** `ALTER TABLE ... FORCE ROW LEVEL SECURITY` (lineas 141-2480), y las 23 coinciden 1:1 con las 23 que tienen `CREATE POLICY`. La lista en si (nombres de tablas) es correcta -- el numero "24" en el texto del contexto comun es un off-by-one; no afecta el trabajo, se documenta por transparencia (regla "verificar antes de arreglar").

## Hallazgos transversales (code paths de riesgo)

1. **`current_family_id()` devuelve `NULL` cuando no hay contexto seteado** (`db/structure.sql:63-72`, `NULLIF(current_setting('app.current_family_id', true), '')::uuid`).
   Con FORCE, `family_id = NULL` nunca es TRUE, asi que cualquier INSERT/UPDATE/SELECT sobre una tabla FORCE sin contexto
   seteado es bloqueado (WITH CHECK) o no devuelve filas (USING). Esto es la base de todo el analisis de riesgo de abajo.

2. **`RlsContext.set_family` en requests solo corre DESPUES de resolver la sesion**
   (`app/controllers/concerns/authentication.rb:19-22`): `find_session_by_cookie` hace `Session.find_by(id: cookie_value)`
   sin contexto, y recien despues `RlsContext.set_family(Current.family&.id)`. Correcto por diseno -- `sessions`/`users` no
   tienen RLS y no podrian tenerla (se consultan antes de saber la family). Mismo patron en
   `app/controllers/api/v1/base_controller.rb:320` para API keys.

3. **`RowLevelSecurity` (controller concern) es solo la red de seguridad de RESET, no el SET**
   (`app/controllers/concerns/row_level_security.rb`): el `around_action` corre ANTES que `authenticate_user!` en la cadena
   de filtros, asi que su `yield` no hace nada util -- solo el `ensure RlsContext.reset` importa, para que una conexion
   reciclada del pool nunca arrastre un `app.current_family_id` de un request anterior al siguiente que la reutilice.
   Confirmado leyendo el comentario en el propio archivo.

4. **`WebhooksController` hace `skip_authentication`** (linea 3), por lo que NINGUN webhook (Plaid, Plaid EU, Stripe, y los
   que falten por revisar) corre con `app.current_family_id` seteado. Verificado en profundidad para Plaid
   (`app/models/plaid_item/webhook_processor.rb`): el processor solo hace `PlaidItem.find_by(plaid_id:)` (tabla sin RLS,
   OK) y `plaid_item.sync_later` / `plaid_item.update!(status:)` (tambien sin RLS). El trabajo real sobre tablas FORCE
   (accounts, entries, transactions...) ocurre en el job encolado, que SI setea RLS correctamente via
   `ActiveJobRowLevelSecurity` (`extract_family` reconoce `arg.respond_to?(:family)`, y `PlaidItem#family` existe). **No
   verificado linea por linea para los otros ~10 procesadores de webhook/provider** (SimpleFin, Coinbase, Mercury,
   Sophtron, etc.) ni para el webhook de Stripe -- mismo patron asumido por analogia de codigo, pendiente de confirmar en
   Etapa B/C.

5. **Jobs del `config/schedule.yml`**:
   - `SyncHourlyJob` (`app/jobs/sync_hourly_job.rb:22`) y `InactiveFamilyCleanerJob` (:21) y `DemoFamilyRefreshJob` (:18)
     **SI** usan `RlsContext.with_family(...)` explicitamente por cada family/item iterado.
   - `SyncCleanerJob` (`Sync.clean`), `DataCleanerJob` (`FamilyMerchantAssociation...delete_all`,
     `ArchivedExport.expired.destroy_all`) y `SecurityHealthCheckJob` (`Security::HealthChecker.check_all`) **NO** usan
     RlsContext y operan cross-family. Hoy es inofensivo porque `syncs`, `family_merchant_associations` y
     `archived_exports` no tienen RLS -- pero es la prueba concreta de que si Ola 2 le agrega FORCE a `syncs` (candidata
     obvia: unica tabla con `family_id` propio y cero proteccion), estos jobs se rompen salvo que se reescriban para
     iterar por family o corran con un rol que tenga BYPASSRLS explicito y documentado.
   - `ImportMarketDataJob` solo toca tablas `global` (securities/security_prices/exchange_rates) -- no necesita RLS.

6. **Paneles super_admin / impersonacion** (`app/controllers/admin/*`, `app/controllers/impersonation_sessions_controller.rb`,
   `app/controllers/concerns/impersonatable.rb`): por diseno cruzan families (es su proposito). `impersonation_sessions`,
   `impersonation_session_logs`, `sso_providers`, `sso_audit_logs` no tienen RLS -- consistente con ser superficie
   admin-only, protegida (se asume) a nivel de autorizacion de controller/rol, no a nivel de family. **No se audito en
   esta etapa si `admin/*_controller.rb` verifica `current_user.super_admin?` de forma consistente** -- eso es
   autorizacion de aplicacion, no RLS, y queda fuera del alcance de E1-A pero es un candidate obvio para una etapa de
   autorizacion.

7. **`platform_daily_metrics`**: global por definicion (metricas agregadas cross-family para el dashboard de super_admin).

8. **Active Storage** (`active_storage_attachments/blobs/variant_records`): tablas de framework sin columna de family.
   La proteccion depende 100% de que el `record` polymorphic (Account#logo, FamilyDocument, ArchivedExport#export_file,
   etc.) este correctamente scoped, MAS de que las rutas de descarga (`/rails/active_storage/blobs/:signed_id/*`) esten
   protegidas. **No se encontro un controller propio que override esas rutas** en esta pasada de `app/controllers` --
   si la app usa las rutas default de Rails para servir blobs, un signed id filtrado (logs, historial compartido) es
   suficiente para descargar el archivo sin ningun chequeo de family. Riesgo ALTO a confirmar explicitamente en la
   proxima etapa (grep de `config/routes.rb` por `active_storage` y de vistas por `rails_blob_path`/`url_for` con
   `disposition:`).

9. **Rake tasks y mailers**: no se auditaron exhaustivamente en esta etapa (fuera del scope estricto de "code paths sin
   family context" que pide E1-A, pero declarado explicitamente como NO cubierto por honestidad -- ver seccion final).

## Tabla completa (114 filas)
| Tabla | Clase | Clasificacion | Cadena a family | Policy RLS | FORCE |
|---|---|---|---|---|---|
| `families` | Family | root | families.id es la raiz del grafo | ninguna | no |
| `accounts` | Account | direct | accounts.family_id | SI | SI |
| `binance_items` | BinanceItem | direct | binance_items.family_id | ninguna | no |
| `budgets` | Budget | direct | budgets.family_id | SI | SI |
| `categories` | Category | direct | categories.family_id | SI | SI |
| `coinbase_items` | CoinbaseItem | direct | coinbase_items.family_id | ninguna | no |
| `coinstats_items` | CoinstatsItem | direct | coinstats_items.family_id | ninguna | no |
| `enable_banking_items` | EnableBankingItem | direct | enable_banking_items.family_id | ninguna | no |
| `family_documents` | FamilyDocument | direct | family_documents.family_id | ninguna | no |
| `family_exports` | FamilyExport | direct | family_exports.family_id | ninguna | no |
| `family_merchant_associations` | FamilyMerchantAssociation | direct | family_merchant_associations.family_id | ninguna | no |
| `fleet_vehicles` | FleetVehicle | direct | fleet_vehicles.family_id | SI | SI |
| `goals` | Goal | direct | goals.family_id | SI | SI |
| `imports` | Import | direct | imports.family_id | ninguna | no |
| `indexa_capital_items` | IndexaCapitalItem | direct | indexa_capital_items.family_id | ninguna | no |
| `invitations` | Invitation | direct | invitations.family_id | ninguna | no |
| `llm_usages` | LlmUsage | direct | llm_usages.family_id | ninguna | no |
| `lunchflow_items` | LunchflowItem | direct | lunchflow_items.family_id | ninguna | no |
| `mercury_items` | MercuryItem | direct | mercury_items.family_id | ninguna | no |
| `plaid_items` | PlaidItem | direct | plaid_items.family_id | ninguna | no |
| `products` | Product | direct | products.family_id | SI | SI |
| `purchase_orders` | PurchaseOrder | direct | purchase_orders.family_id | SI | SI |
| `receivables` | Receivable | direct | receivables.family_id | SI | SI |
| `recurring_transactions` | RecurringTransaction | direct | recurring_transactions.family_id | SI | SI |
| `rules` | Rule | direct | rules.family_id | SI | SI |
| `sales` | Sale | direct | sales.family_id | SI | SI |
| `simplefin_items` | SimplefinItem | direct | simplefin_items.family_id | ninguna | no |
| `snaptrade_items` | SnaptradeItem | direct | snaptrade_items.family_id | ninguna | no |
| `sophtron_items` | SophtronItem | direct | sophtron_items.family_id | ninguna | no |
| `statement_imports` | StatementImport | direct | statement_imports.family_id | ninguna | no |
| `subscriptions` | Subscription | direct | subscriptions.family_id | ninguna | no |
| `syncs` | Sync | direct | syncs.family_id | ninguna | no |
| `tags` | Tag | direct | tags.family_id | SI | SI |
| `transactions` | Transaction | direct | transactions.family_id | SI | SI |
| `valuations` | Valuation | direct | valuations.family_id | SI | SI |
| `versions` | Version | direct | versions.family_id (PaperTrail) | SI | SI |
| `merchants` | Merchant | direct-nullable | merchants.family_id (NULL para ProviderMerchant globales via STI type) | SI | SI |
| `account_providers` | AccountProvider | indirect | account_providers.account_id -> accounts.family_id | ninguna | no |
| `account_shares` | AccountShare | indirect | account_shares.account_id -> accounts.family_id | ninguna | no |
| `addresses` | Address | indirect | addresses.addressable_id/type -> hoy solo Property -> accounts.accountable reverse -> accounts.family_id | ninguna | no |
| `balances` | Balance | indirect | balances.account_id -> accounts.family_id | ninguna | no |
| `binance_accounts` | BinanceAccount | indirect | binance_accounts.binance_item_id -> binance_items.family_id | ninguna | no |
| `budget_categories` | BudgetCategory | indirect | budget_categories.budget_id -> budgets.family_id | SI | SI |
| `chats` | Chat | indirect | chats.user_id -> users.family_id | ninguna | no |
| `coinbase_accounts` | CoinbaseAccount | indirect | coinbase_accounts.coinbase_item_id -> coinbase_items.family_id | ninguna | no |
| `coinstats_accounts` | CoinstatsAccount | indirect | coinstats_accounts.coinstats_item_id -> coinstats_items.family_id | ninguna | no |
| `credit_cards` | CreditCard | indirect | accounts.accountable_id/type = credit_cards.id (reverse FK, NO columna family_id/account_id en credit_cards) -> accounts.family_id | ninguna | no |
| `cryptos` | Crypto | indirect | accounts.accountable_id/type = cryptos.id (reverse FK, NO columna family_id/account_id en cryptos) -> accounts.family_id | ninguna | no |
| `data_enrichments` | DataEnrichment | indirect | data_enrichments.enrichable_id/type -> hoy solo Entryable (Transaction/Valuation/Trade) -> ... -> family_id | ninguna | no |
| `depositories` | Depository | indirect | accounts.accountable_id/type = depositories.id (reverse FK, NO columna family_id/account_id en depositories) -> accounts.family_id | ninguna | no |
| `enable_banking_accounts` | EnableBankingAccount | indirect | enable_banking_accounts.enable_banking_item_id -> enable_banking_items.family_id | ninguna | no |
| `entries` | Entry | indirect | entries.account_id -> accounts.family_id | SI | SI |
| `fuel_log_lines` | FuelLogLine | indirect | fuel_log_lines.fuel_log_id -> fuel_logs.fleet_vehicle_id -> fleet_vehicles.family_id | SI | SI |
| `fuel_logs` | FuelLog | indirect | fuel_logs.fleet_vehicle_id -> fleet_vehicles.family_id | SI | SI |
| `goal_accounts` | GoalAccount | indirect | goal_accounts.goal_id -> goals.family_id | ninguna | no |
| `goal_pledges` | GoalPledge | indirect | goal_pledges.goal_id -> goals.family_id | ninguna | no |
| `holdings` | Holding | indirect | holdings.account_id -> accounts.family_id | ninguna | no |
| `import_mappings` | ImportMapping | indirect | import_mappings.import_id -> imports.family_id | ninguna | no |
| `import_rows` | ImportRow | indirect | import_rows.import_id -> imports.family_id | ninguna | no |
| `indexa_capital_accounts` | IndexaCapitalAccount | indirect | indexa_capital_accounts.indexa_capital_item_id -> indexa_capital_items.family_id | ninguna | no |
| `investments` | Investment | indirect | accounts.accountable_id/type = investments.id (reverse FK, NO columna family_id/account_id en investments) -> accounts.family_id | ninguna | no |
| `loans` | Loan | indirect | accounts.accountable_id/type = loans.id (reverse FK, NO columna family_id/account_id en loans) -> accounts.family_id | ninguna | no |
| `lunchflow_accounts` | LunchflowAccount | indirect | lunchflow_accounts.lunchflow_item_id -> lunchflow_items.family_id | ninguna | no |
| `mercury_accounts` | MercuryAccount | indirect | mercury_accounts.mercury_item_id -> mercury_items.family_id | ninguna | no |
| `messages` | Message | indirect | messages.chat_id -> chats.user_id -> users.family_id | ninguna | no |
| `mobile_devices` | MobileDevice | indirect | mobile_devices.user_id -> users.family_id | ninguna | no |
| `other_assets` | OtherAsset | indirect | accounts.accountable_id/type = other_assets.id (reverse FK, NO columna family_id/account_id en other_assets) -> accounts.family_id | ninguna | no |
| `other_liabilities` | OtherLiability | indirect | accounts.accountable_id/type = other_liabilities.id (reverse FK, NO columna family_id/account_id en other_liabilities) -> accounts.family_id | ninguna | no |
| `plaid_accounts` | PlaidAccount | indirect | plaid_accounts.plaid_item_id -> plaid_items.family_id | ninguna | no |
| `product_stock_movements` | ProductStockMovement | indirect | product_stock_movements.product_id -> products.family_id | SI | SI |
| `properties` | Property | indirect | accounts.accountable_id/type = properties.id (reverse FK, NO columna family_id/account_id en properties) -> accounts.family_id | ninguna | no |
| `purchase_order_items` | PurchaseOrderItem | indirect | purchase_order_items.purchase_order_id -> purchase_orders.family_id | SI | SI |
| `rejected_transfers` | RejectedTransfer | indirect | rejected_transfers.inflow_transaction_id/outflow_transaction_id -> transactions.family_id | ninguna | no |
| `rule_actions` | RuleAction | indirect | rule_actions.rule_id -> rules.family_id | ninguna | no |
| `rule_conditions` | RuleCondition | indirect | rule_conditions.rule_id -> rules.family_id (self-referencial via parent_id para condiciones anidadas) | ninguna | no |
| `rule_runs` | RuleRun | indirect | rule_runs.rule_id -> rules.family_id | ninguna | no |
| `sale_items` | SaleItem | indirect | sale_items.sale_id -> sales.family_id | SI | SI |
| `simplefin_accounts` | SimplefinAccount | indirect | simplefin_accounts.simplefin_item_id -> simplefin_items.family_id | ninguna | no |
| `snaptrade_accounts` | SnaptradeAccount | indirect | snaptrade_accounts.snaptrade_item_id -> snaptrade_items.family_id | ninguna | no |
| `sophtron_accounts` | SophtronAccount | indirect | sophtron_accounts.sophtron_item_id -> sophtron_items.family_id | ninguna | no |
| `taggings` | Tagging | indirect | taggings.tag_id -> tags.family_id (taggable polymorphic: hoy solo Transaction) | ninguna | no |
| `tool_calls` | ToolCall | indirect | tool_calls.message_id -> messages.chat_id -> chats.user_id -> users.family_id | ninguna | no |
| `trades` | Trade | indirect | entries.entryable_id/type = trades.id (reverse FK, sin columna family_id/account_id) -> entries.account_id -> accounts.family_id | ninguna | no |
| `transfers` | Transfer | indirect | transfers.inflow_transaction_id/outflow_transaction_id -> transactions.family_id (ambas patas deberian ser de la MISMA family) | ninguna | no |
| `vehicles` | Vehicle | indirect | accounts.accountable_id/type = vehicles.id (reverse FK, NO columna family_id/account_id en vehicles) -> accounts.family_id | ninguna | no |
| `api_keys` | ApiKey | auth | api_keys.user_id -> users.family_id | ninguna | no |
| `archived_exports` | ArchivedExport | auth | sin family_id -- se accede exclusivamente por `find_by_download_token!(token)` (digest SHA256 del token) | ninguna | no |
| `impersonation_session_logs` | ImpersonationSessionLog | auth | impersonation_session_logs.impersonation_session_id -> impersonation_sessions | ninguna | no |
| `impersonation_sessions` | ImpersonationSession | auth | impersonation_sessions.impersonator_id/impersonated_id -> users | ninguna | no |
| `invite_codes` | InviteCode | auth | sin family_id -- codigo de invitacion self-hosted (no ligado a una family existente) | ninguna | no |
| `oauth_access_grants` | OauthAccessGrant | auth | oauth_access_grants.resource_owner_id -> users.family_id | ninguna | no |
| `oauth_access_tokens` | OauthAccessToken | auth | oauth_access_tokens.resource_owner_id -> users.family_id | ninguna | no |
| `oauth_applications` | OauthApplication | auth | oauth_applications.owner_id/type (polymorphic, probablemente User o admin) | ninguna | no |
| `oidc_identities` | OidcIdentity | auth | oidc_identities.user_id -> users.family_id | ninguna | no |
| `sessions` | Session | auth | sessions.user_id -> users.family_id | ninguna | no |
| `sso_audit_logs` | SsoAuditLog | auth | sso_audit_logs.user_id -> users.family_id | ninguna | no |
| `sso_providers` | SsoProvider | auth | sin family_id -- configuracion de proveedor SSO (client_id, client_secret encriptado) | ninguna | no |
| `users` | User | auth | users.family_id (propio, pero la tabla se consulta ANTES de conocer la family) | ninguna | no |
| `webauthn_credentials` | WebauthnCredential | auth | webauthn_credentials.user_id -> users.family_id | ninguna | no |
| `ar_internal_metadata` | ActiveRecord::InternalMetadata | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `eval_datasets` | Eval::Dataset | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `eval_results` | Eval::Result | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `eval_runs` | Eval::Run | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `eval_samples` | Eval::Sample | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `exchange_rate_pairs` | ExchangeRatePair | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `exchange_rates` | ExchangeRate | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `platform_daily_metrics` | PlatformDailyMetric | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `schema_migrations` | SchemaMigration | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `securities` | Security | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `security_prices` | SecurityPrice | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `settings` | Setting | global | N/A (genuinamente global, sin relacion a family) | ninguna | no |
| `active_storage_attachments` | ActiveStorage::Attachment | storage | active_storage_attachments.record_id/type -> polymorphic (Account#logo, FamilyDocument, ArchivedExport#export_file, etc) -> family via el record | ninguna | no |
| `active_storage_blobs` | ActiveStorage::Blob | storage | active_storage_attachments.record_id/type -> polymorphic (Account#logo, FamilyDocument, ArchivedExport#export_file, etc) -> family via el record | ninguna | no |
| `active_storage_variant_records` | ActiveStorage::VariantRecord | storage | active_storage_attachments.record_id/type -> polymorphic (Account#logo, FamilyDocument, ArchivedExport#export_file, etc) -> family via el record | ninguna | no |

## Detalle por tabla (clasificacion, policy exacta, notas y code paths de riesgo)

### `families` (Family)
- **Clasificacion**: root
- **Cadena a family**: families.id es la raiz del grafo
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Tabla ancla; no tiene RLS (no aplicaria, es ella misma la unidad de aislamiento) pero SI se consulta en super_admin/impersonation/rake/demo-refresh sin restriccion -- correcto por diseno, ya que esas rutas son platform-level, no request-scoped.
- **Code paths de riesgo / a verificar**: Confirmar que ningun controller de usuario final expone Family.find/.all sin pasar por Current.family.

### `accounts` (Account)
- **Clasificacion**: direct
- **Cadena a family**: accounts.family_id
- **Policy RLS**: accounts_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si
- **Notas**: Cuenta raiz de casi todo el grafo financiero (accountable, entries).
- **Code paths de riesgo / a verificar**: Ninguno detectado fuera de request/job flow estandar; Account.find_by(plaid_account_id:)/simplefin_account_id en sync jobs corre ya dentro de RlsContext.with_family via ActiveJobRowLevelSecurity.

### `binance_items` (BinanceItem)
- **Clasificacion**: direct
- **Cadena a family**: binance_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, binance_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `budgets` (Budget)
- **Clasificacion**: direct
- **Cadena a family**: budgets.family_id
- **Policy RLS**: budgets_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `categories` (Category)
- **Clasificacion**: direct
- **Cadena a family**: categories.family_id
- **Policy RLS**: categories_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `coinbase_items` (CoinbaseItem)
- **Clasificacion**: direct
- **Cadena a family**: coinbase_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, coinbase_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `coinstats_items` (CoinstatsItem)
- **Clasificacion**: direct
- **Cadena a family**: coinstats_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, coinstats_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `enable_banking_items` (EnableBankingItem)
- **Clasificacion**: direct
- **Cadena a family**: enable_banking_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, enable_banking_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `family_documents` (FamilyDocument)
- **Clasificacion**: direct
- **Cadena a family**: family_documents.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Active Storage attachment adjunto (provider_file_id + Active Storage).
- **Code paths de riesgo / a verificar**: Descarga via signed Active Storage id -- ver active_storage_attachments/blobs mas abajo.

### `family_exports` (FamilyExport)
- **Clasificacion**: direct
- **Cadena a family**: family_exports.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: Export descargable, probablemente via token/signed id similar a ArchivedExport -- confirmar si usa el mismo patron `find_by_download_token!` sin family scoping.

### `family_merchant_associations` (FamilyMerchantAssociation)
- **Clasificacion**: direct
- **Cadena a family**: family_merchant_associations.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: link entre family y ProviderMerchant global.
- **Code paths de riesgo / a verificar**: SIN RLS (no esta en la lista de 23). DataCleanerJob#clean_old_merchant_associations hace `FamilyMerchantAssociation.where(unlinked_at: ...).delete_all` CROSS-FAMILY sin RlsContext -- inofensivo hoy porque no hay policy que lo bloquee/filtre, pero es la prueba de que si se agrega RLS a esta tabla en el futuro, este job rompe salvo que itere por family.

### `fleet_vehicles` (FleetVehicle)
- **Clasificacion**: direct
- **Cadena a family**: fleet_vehicles.family_id
- **Policy RLS**: fleet_vehicles_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `goals` (Goal)
- **Clasificacion**: direct
- **Cadena a family**: goals.family_id
- **Policy RLS**: goals_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `imports` (Import)
- **Clasificacion**: direct
- **Cadena a family**: imports.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Tambien account_id.
- **Code paths de riesgo / a verificar**: SIN RLS (no esta en la lista de 23) pese a ser family_id directo -- import es el punto de entrada de datos financieros bulk (CSV/QIF/Mint), candidato claro a FORCE en Ola 2/3.

### `indexa_capital_items` (IndexaCapitalItem)
- **Clasificacion**: direct
- **Cadena a family**: indexa_capital_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, indexa_capital_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `invitations` (Invitation)
- **Clasificacion**: direct
- **Cadena a family**: invitations.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: Invitations se buscan por token (`Invitation.find_by(token:)` esperado) en el flujo de aceptar invitacion, ANTES de que exista family context (el usuario que acepta aun no es miembro). Ese find_by no puede depender de current_family_id(); confirmar que el controller de aceptacion no hace ningun otro query family-scoped antes de crear la membership.

### `llm_usages` (LlmUsage)
- **Clasificacion**: direct
- **Cadena a family**: llm_usages.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Metrica de billing por family.
- **Code paths de riesgo / a verificar**: SIN RLS (no esta en la lista de 23) pese a ser dato sensible de billing/uso de IA por family.

### `lunchflow_items` (LunchflowItem)
- **Clasificacion**: direct
- **Cadena a family**: lunchflow_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, lunchflow_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `mercury_items` (MercuryItem)
- **Clasificacion**: direct
- **Cadena a family**: mercury_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, mercury_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `plaid_items` (PlaidItem)
- **Clasificacion**: direct
- **Cadena a family**: plaid_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, plaid_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `products` (Product)
- **Clasificacion**: direct
- **Cadena a family**: products.family_id
- **Policy RLS**: products_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `purchase_orders` (PurchaseOrder)
- **Clasificacion**: direct
- **Cadena a family**: purchase_orders.family_id
- **Policy RLS**: purchase_orders_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si
- **Notas**: Tambien account_id/entry_id (redundante, ya family-scoped).

### `receivables` (Receivable)
- **Clasificacion**: direct
- **Cadena a family**: receivables.family_id
- **Policy RLS**: receivables_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `recurring_transactions` (RecurringTransaction)
- **Clasificacion**: direct
- **Cadena a family**: recurring_transactions.family_id
- **Policy RLS**: recurring_transactions_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si
- **Notas**: Tambien account_id/merchant_id (redundante).

### `rules` (Rule)
- **Clasificacion**: direct
- **Cadena a family**: rules.family_id
- **Policy RLS**: rules_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `sales` (Sale)
- **Clasificacion**: direct
- **Cadena a family**: sales.family_id
- **Policy RLS**: sales_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si
- **Notas**: Tambien account_id/entry_id (redundante).

### `simplefin_items` (SimplefinItem)
- **Clasificacion**: direct
- **Cadena a family**: simplefin_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, simplefin_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `snaptrade_items` (SnaptradeItem)
- **Clasificacion**: direct
- **Cadena a family**: snaptrade_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, snaptrade_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `sophtron_items` (SophtronItem)
- **Clasificacion**: direct
- **Cadena a family**: sophtron_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Credencial/conexion de integracion bancaria/exchange.
- **Code paths de riesgo / a verificar**: Se resuelve por plaid_id/token en webhooks (ver WebhooksController) y en jobs de sync via ActiveJobRowLevelSecurity#extract_family (arg.respond_to?(:family)). Confirmado para Plaid: WebhookProcessor hace `PlaidItem.find_by(plaid_id:)` SIN family context (correcto, sophtron_items no tiene RLS) y solo encola `sync_later`, que SI corre dentro de RlsContext.with_family via el job. Mismo patron asumido (no verificado linea por linea) para los otros 10 providers.

### `statement_imports` (StatementImport)
- **Clasificacion**: direct
- **Cadena a family**: statement_imports.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Tambien user_id.
- **Code paths de riesgo / a verificar**: Se referencia en ActiveJobRowLevelSecurity#extract_family_from_hash/id (statement_import_id) -- confirma que los jobs que la usan SI resuelven family correctamente. SIN RLS propia sin embargo.

### `subscriptions` (Subscription)
- **Clasificacion**: direct
- **Cadena a family**: subscriptions.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Stripe billing.
- **Code paths de riesgo / a verificar**: SIN RLS. subscriptions.stripe_id se consulta en el webhook de Stripe (WebhooksController#stripe, skip_authentication) -- ese lookup necesariamente corre sin family context; confirmar que el processor de Stripe resuelve la family DESPUES via el subscription/customer id y no asume ningun otro modelo protegido.

### `syncs` (Sync)
- **Clasificacion**: direct
- **Cadena a family**: syncs.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: syncable polymorphic (PlaidItem, SimplefinItem, etc, y self via parent_id).
- **Code paths de riesgo / a verificar**: SIN RLS pese a tener family_id propio -- unica tabla de la lista con family_id directo y CERO politica ni ENABLE. SyncCleanerJob (`Sync.clean`, cron horario) opera cross-family sin RlsContext; hoy no importa porque no hay policy, pero es la brecha mas clara para Ola 2: agregar FORCE aqui sin romper este job requiere que Sync.clean itere por family o corra como rol con BYPASSRLS explicito.

### `tags` (Tag)
- **Clasificacion**: direct
- **Cadena a family**: tags.family_id
- **Policy RLS**: tags_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si

### `transactions` (Transaction)
- **Clasificacion**: direct
- **Cadena a family**: transactions.family_id
- **Policy RLS**: transactions_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si
- **Notas**: entryable de Entry; category_id/merchant_id secundarios.

### `valuations` (Valuation)
- **Clasificacion**: direct
- **Cadena a family**: valuations.family_id
- **Policy RLS**: valuations_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si
- **Notas**: entryable de Entry.

### `versions` (Version)
- **Clasificacion**: direct
- **Cadena a family**: versions.family_id (PaperTrail)
- **Policy RLS**: versions_family_isolation_policy USING/CHECK (family_id = current_family_id())
- **FORCE**: si
- **Notas**: item_type/item_id polymorphic al record versionado.
- **Code paths de riesgo / a verificar**: Si PaperTrail crea versions dentro de un job/request sin RlsContext seteado (p.ej. un rake task de datos), el INSERT falla el WITH CHECK y se pierde el audit trail silenciosamente (o el job entero falla) -- confirmar que ExpiredFamilyCleaner/rake tasks que tocan modelos versionados corren con family context.

### `merchants` (Merchant)
- **Clasificacion**: direct-nullable
- **Cadena a family**: merchants.family_id (NULL para ProviderMerchant globales via STI type)
- **Policy RLS**: merchants_family_isolation_policy USING/CHECK (family_id = current_family_id() OR family_id IS NULL)
- **FORCE**: si
- **Notas**: STI: FamilyMerchant (family_id NOT NULL) vs ProviderMerchant (family_id NULL, catalogo global compartido).
- **Code paths de riesgo / a verificar**: ProviderMerchant.convert_to_family_merchant_for(family) escribe en la misma tabla; validar que el INSERT setea family_id antes de pasar por WITH CHECK.

### `account_providers` (AccountProvider)
- **Clasificacion**: indirect
- **Cadena a family**: account_providers.account_id -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: join table Account<->Provider (Plaid/SimpleFin/etc, polymorphic provider_type/provider_id).
- **Code paths de riesgo / a verificar**: SIN RLS.

### `account_shares` (AccountShare)
- **Clasificacion**: indirect
- **Cadena a family**: account_shares.account_id -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Tambien user_id (comparticion de cuenta entre usuarios de la misma family, presumiblemente).
- **Code paths de riesgo / a verificar**: SIN RLS; si en el futuro permite compartir cross-family (feature no confirmada), esta tabla es el punto critico a auditar primero.

### `addresses` (Address)
- **Clasificacion**: indirect
- **Cadena a family**: addresses.addressable_id/type -> hoy solo Property -> accounts.accountable reverse -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: addressable polymorphic, unico consumidor detectado: Property.
- **Code paths de riesgo / a verificar**: Cadena de 3 saltos sin ninguna columna de family en el camino (Property tampoco tiene family_id). SIN RLS.

### `balances` (Balance)
- **Clasificacion**: indirect
- **Cadena a family**: balances.account_id -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Snapshot diario de saldo.
- **Code paths de riesgo / a verificar**: SIN RLS; usado por ImportMarketDataJob/sync jobs en volumen -- confirmar que siempre se escribe via `account.balances.create` con el account ya scoped.

### `binance_accounts` (BinanceAccount)
- **Clasificacion**: indirect
- **Cadena a family**: binance_accounts.binance_item_id -> binance_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `budget_categories` (BudgetCategory)
- **Clasificacion**: indirect
- **Cadena a family**: budget_categories.budget_id -> budgets.family_id
- **Policy RLS**: budget_categories_family_isolation_policy USING/CHECK (budget_id IN (SELECT id FROM budgets WHERE family_id = current_family_id()))
- **FORCE**: si
- **Notas**: Policy usa subquery a budgets, no columna propia.

### `chats` (Chat)
- **Clasificacion**: indirect
- **Cadena a family**: chats.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Asistente IA.
- **Code paths de riesgo / a verificar**: SIN RLS; el asistente LLM lee/escribe chats y messages -- si algun tool-call del asistente arma SQL crudo (connection.execute) fuera del ORM, no hay red de seguridad de DB.

### `coinbase_accounts` (CoinbaseAccount)
- **Clasificacion**: indirect
- **Cadena a family**: coinbase_accounts.coinbase_item_id -> coinbase_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `coinstats_accounts` (CoinstatsAccount)
- **Clasificacion**: indirect
- **Cadena a family**: coinstats_accounts.coinstats_item_id -> coinstats_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `credit_cards` (CreditCard)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = credit_cards.id (reverse FK, NO columna family_id/account_id en credit_cards) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: credit_cards no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre CreditCard (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `cryptos` (Crypto)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = cryptos.id (reverse FK, NO columna family_id/account_id en cryptos) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: cryptos no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre Crypto (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `data_enrichments` (DataEnrichment)
- **Clasificacion**: indirect
- **Cadena a family**: data_enrichments.enrichable_id/type -> hoy solo Entryable (Transaction/Valuation/Trade) -> ... -> family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: include Enrichable en Entryable; guarda el valor "pre-AI-enrichment" de un campo para poder revertir.
- **Code paths de riesgo / a verificar**: SIN RLS. Contiene copias de datos financieros (valores pre-enriquecimiento) fuera del perimetro RLS de transactions/valuations/trades.

### `depositories` (Depository)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = depositories.id (reverse FK, NO columna family_id/account_id en depositories) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: depositories no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre Depository (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `enable_banking_accounts` (EnableBankingAccount)
- **Clasificacion**: indirect
- **Cadena a family**: enable_banking_accounts.enable_banking_item_id -> enable_banking_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `entries` (Entry)
- **Clasificacion**: indirect
- **Cadena a family**: entries.account_id -> accounts.family_id
- **Policy RLS**: entries_family_isolation_policy USING/CHECK (account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))
- **FORCE**: si
- **Notas**: entryable delegated_type (Transaction/Valuation/Trade).

### `fuel_log_lines` (FuelLogLine)
- **Clasificacion**: indirect
- **Cadena a family**: fuel_log_lines.fuel_log_id -> fuel_logs.fleet_vehicle_id -> fleet_vehicles.family_id
- **Policy RLS**: fuel_log_lines_family_isolation_policy USING/CHECK (fuel_log_id IN (SELECT id FROM fuel_logs WHERE fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id())))
- **FORCE**: si
- **Notas**: Chain de 2 saltos.

### `fuel_logs` (FuelLog)
- **Clasificacion**: indirect
- **Cadena a family**: fuel_logs.fleet_vehicle_id -> fleet_vehicles.family_id
- **Policy RLS**: fuel_logs_family_isolation_policy USING/CHECK (fleet_vehicle_id IN (SELECT id FROM fleet_vehicles WHERE family_id = current_family_id()))
- **FORCE**: si
- **Notas**: Tambien tiene account_id/entry_id propios (ya family-scoped) pero la policy usa el chain via fleet_vehicle.

### `goal_accounts` (GoalAccount)
- **Clasificacion**: indirect
- **Cadena a family**: goal_accounts.goal_id -> goals.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: join table goal<->account; SIN policy/RLS propia pese a que goals SI tiene FORCE.
- **Code paths de riesgo / a verificar**: goal_accounts no esta en la lista de 23 tablas con RLS: escritura/lectura directa (find_by, joins) no pasa por ninguna policy; solo queda protegida indirectamente si el code path siempre filtra por goal ya scoped por su asociacion `has_many :goal_accounts` a traves de Goal (belongs_to family). Verificar controllers de metas.

### `goal_pledges` (GoalPledge)
- **Clasificacion**: indirect
- **Cadena a family**: goal_pledges.goal_id -> goals.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Tambien tiene account_id y matched_transaction_id (ambos ya family-scoped, paths redundantes).
- **Code paths de riesgo / a verificar**: Igual que goal_accounts: sin RLS propia, depende de que Goal#goal_pledges siempre pase por un goal ya scoped por controller.

### `holdings` (Holding)
- **Clasificacion**: indirect
- **Cadena a family**: holdings.account_id -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Tambien security_id/account_provider_id/provider_security_id.
- **Code paths de riesgo / a verificar**: SIN RLS pese a tener account_id directo.

### `import_mappings` (ImportMapping)
- **Clasificacion**: indirect
- **Cadena a family**: import_mappings.import_id -> imports.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: mappable polymorphic.
- **Code paths de riesgo / a verificar**: SIN RLS; imports SI tiene family_id directo pero tampoco tiene RLS (ver imports).

### `import_rows` (ImportRow)
- **Clasificacion**: indirect
- **Cadena a family**: import_rows.import_id -> imports.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS.

### `indexa_capital_accounts` (IndexaCapitalAccount)
- **Clasificacion**: indirect
- **Cadena a family**: indexa_capital_accounts.indexa_capital_item_id -> indexa_capital_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `investments` (Investment)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = investments.id (reverse FK, NO columna family_id/account_id en investments) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: investments no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre Investment (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `loans` (Loan)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = loans.id (reverse FK, NO columna family_id/account_id en loans) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: loans no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre Loan (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `lunchflow_accounts` (LunchflowAccount)
- **Clasificacion**: indirect
- **Cadena a family**: lunchflow_accounts.lunchflow_item_id -> lunchflow_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `mercury_accounts` (MercuryAccount)
- **Clasificacion**: indirect
- **Cadena a family**: mercury_accounts.mercury_item_id -> mercury_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `messages` (Message)
- **Clasificacion**: indirect
- **Cadena a family**: messages.chat_id -> chats.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Cadena de 2 saltos.
- **Code paths de riesgo / a verificar**: SIN RLS.

### `mobile_devices` (MobileDevice)
- **Clasificacion**: indirect
- **Cadena a family**: mobile_devices.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Push notification device registration; tambien referenciado desde oauth_access_tokens.mobile_device_id.
- **Code paths de riesgo / a verificar**: SIN RLS; se consulta en flujos de push/OAuth mobile potencialmente pre-family-context.

### `other_assets` (OtherAsset)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = other_assets.id (reverse FK, NO columna family_id/account_id en other_assets) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: other_assets no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre OtherAsset (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `other_liabilities` (OtherLiability)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = other_liabilities.id (reverse FK, NO columna family_id/account_id en other_liabilities) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: other_liabilities no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre OtherLiability (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `plaid_accounts` (PlaidAccount)
- **Clasificacion**: indirect
- **Cadena a family**: plaid_accounts.plaid_item_id -> plaid_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `product_stock_movements` (ProductStockMovement)
- **Clasificacion**: indirect
- **Cadena a family**: product_stock_movements.product_id -> products.family_id
- **Policy RLS**: product_stock_movements_family_isolation_policy USING/CHECK (product_id IN (SELECT id FROM products WHERE family_id = current_family_id()))
- **FORCE**: si

### `properties` (Property)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = properties.id (reverse FK, NO columna family_id/account_id en properties) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: properties no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre Property (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `purchase_order_items` (PurchaseOrderItem)
- **Clasificacion**: indirect
- **Cadena a family**: purchase_order_items.purchase_order_id -> purchase_orders.family_id
- **Policy RLS**: purchase_order_items_family_isolation_policy USING/CHECK (purchase_order_id IN (SELECT id FROM purchase_orders WHERE family_id = current_family_id()))
- **FORCE**: si

### `rejected_transfers` (RejectedTransfer)
- **Clasificacion**: indirect
- **Cadena a family**: rejected_transfers.inflow_transaction_id/outflow_transaction_id -> transactions.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Transferencias candidatas descartadas por el matcher automatico.
- **Code paths de riesgo / a verificar**: SIN RLS, mismo razonamiento que transfers.

### `rule_actions` (RuleAction)
- **Clasificacion**: indirect
- **Cadena a family**: rule_actions.rule_id -> rules.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: SIN RLS propia; rules SI tiene FORCE.
- **Code paths de riesgo / a verificar**: rule_actions/rule_conditions/rule_runs se acceden casi siempre via `rule.actions`/`rule.conditions`/`rule.runs` (ya scoped por el rule padre cargado con family context), pero cualquier find_by(id:) directo sobre estas 3 tablas fuera de esa cadena queda sin protegerse.

### `rule_conditions` (RuleCondition)
- **Clasificacion**: indirect
- **Cadena a family**: rule_conditions.rule_id -> rules.family_id (self-referencial via parent_id para condiciones anidadas)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: Ver nota en rule_actions.

### `rule_runs` (RuleRun)
- **Clasificacion**: indirect
- **Cadena a family**: rule_runs.rule_id -> rules.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: Ver nota en rule_actions.

### `sale_items` (SaleItem)
- **Clasificacion**: indirect
- **Cadena a family**: sale_items.sale_id -> sales.family_id
- **Policy RLS**: sale_items_family_isolation_policy USING/CHECK (sale_id IN (SELECT id FROM sales WHERE family_id = current_family_id()))
- **FORCE**: si

### `simplefin_accounts` (SimplefinAccount)
- **Clasificacion**: indirect
- **Cadena a family**: simplefin_accounts.simplefin_item_id -> simplefin_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `snaptrade_accounts` (SnaptradeAccount)
- **Clasificacion**: indirect
- **Cadena a family**: snaptrade_accounts.snaptrade_item_id -> snaptrade_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `sophtron_accounts` (SophtronAccount)
- **Clasificacion**: indirect
- **Cadena a family**: sophtron_accounts.sophtron_item_id -> sophtron_items.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Code paths de riesgo / a verificar**: SIN RLS; depende de que siempre se acceda via `item.accounts`.

### `taggings` (Tagging)
- **Clasificacion**: indirect
- **Cadena a family**: taggings.tag_id -> tags.family_id (taggable polymorphic: hoy solo Transaction)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: SIN RLS propia; tags SI tiene FORCE.
- **Code paths de riesgo / a verificar**: taggings se crea/lee casi siempre via `transaction.tags`/`tag.taggings`; un find_by(id:) directo sobre taggings queda sin proteger. Confirmar que el taggable (Transaction) y el tag pertenecen a la misma family al crear -- no hay CHECK de integridad cross-family a nivel DB.

### `tool_calls` (ToolCall)
- **Clasificacion**: indirect
- **Cadena a family**: tool_calls.message_id -> messages.chat_id -> chats.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Cadena de 3 saltos.
- **Code paths de riesgo / a verificar**: SIN RLS. Guarda inputs/outputs de tool calls del LLM (potencialmente datos financieros del usuario en texto libre) sin ningun aislamiento a nivel DB.

### `trades` (Trade)
- **Clasificacion**: indirect
- **Cadena a family**: entries.entryable_id/type = trades.id (reverse FK, sin columna family_id/account_id) -> entries.account_id -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :entryable junto con Transaction y Valuation, pero a diferencia de esas dos, Trade NO tiene family_id propio.
- **Code paths de riesgo / a verificar**: entries SI tiene FORCE, pero trades en si no tiene RLS ni columna de scoping. Cualquier acceso a Trade que no pase por `entry.entryable` (p.ej. Trade.find(id) directo en un import de holdings) no esta protegido.

### `transfers` (Transfer)
- **Clasificacion**: indirect
- **Cadena a family**: transfers.inflow_transaction_id/outflow_transaction_id -> transactions.family_id (ambas patas deberian ser de la MISMA family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Representa una transferencia entre 2 cuentas (posiblemente cross-account dentro de la misma family).
- **Code paths de riesgo / a verificar**: SIN RLS. No hay ningun CHECK a nivel DB que garantice que inflow y outflow pertenezcan a la misma family -- si algun bug de la app arma un Transfer entre transactions de 2 families distintas, nada en la DB lo impide.

### `vehicles` (Vehicle)
- **Clasificacion**: indirect
- **Cadena a family**: accounts.accountable_id/type = vehicles.id (reverse FK, NO columna family_id/account_id en vehicles) -> accounts.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: delegated_type :accountable; FamilyIdPropagatable sincroniza family_id hacia el accountable SOLO si el accountable responde a family_id= (estas 9 clases no tienen esa columna, asi que el propagate es un no-op para ellas).
- **Code paths de riesgo / a verificar**: vehicles no tiene NINGUNA columna de scoping propia -> RLS no se puede aplicar directamente sin JOIN a accounts. Hoy 100% de la proteccion es a nivel app (siempre se llega via account.accountable). Un find_by(id:) directo sobre Vehicle (p.ej. en un job de mantenimiento) no tiene ninguna barrera de family.

### `api_keys` (ApiKey)
- **Clasificacion**: auth
- **Cadena a family**: api_keys.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Autenticacion API v1.
- **Code paths de riesgo / a verificar**: app/controllers/api/v1/base_controller.rb linea ~320 hace `RlsContext.set_family(Current.family&.id)` DESPUES de resolver el api key -> mismo patron que sessions. Confirmar el lookup del ApiKey (por token/hash) no dependa de RLS.

### `archived_exports` (ArchivedExport)
- **Clasificacion**: auth
- **Cadena a family**: sin family_id -- se accede exclusivamente por `find_by_download_token!(token)` (digest SHA256 del token)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Export de datos (CSV/PDF) generado por una family, descargable por link con token.
- **Code paths de riesgo / a verificar**: RIESGO: no hay NINGUNA columna family_id/account_id en la tabla. El unico control de acceso es poseer el token (o su digest). Si el token se filtra (logs, referrer, historial de browser compartido), cualquiera puede descargar el export sin pasar por ninguna capa de family/RLS. DataCleanerJob#clean_expired_archived_exports opera cross-family sin RlsContext (inofensivo, no hay RLS que romper). Comparar con family_exports (que SI tiene family_id) para ver si son la misma feature con dos modelos o dos features distintas -- confirmar en Etapa B.

### `impersonation_session_logs` (ImpersonationSessionLog)
- **Clasificacion**: auth
- **Cadena a family**: impersonation_session_logs.impersonation_session_id -> impersonation_sessions
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Audit trail de acciones durante impersonation (controller/action/path/method/ip/user_agent por request).
- **Code paths de riesgo / a verificar**: SIN RLS; mismo razonamiento que impersonation_sessions.

### `impersonation_sessions` (ImpersonationSession)
- **Clasificacion**: auth
- **Cadena a family**: impersonation_sessions.impersonator_id/impersonated_id -> users
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Panel super_admin (Current.session.active_impersonator_session).
- **Code paths de riesgo / a verificar**: SIN RLS; el modelo de acceso es super_admin-only via Impersonatable concern (app/controllers/concerns/impersonatable.rb), no family-scoped por diseno -- el impersonador cruza families intencionalmente.

### `invite_codes` (InviteCode)
- **Clasificacion**: auth
- **Cadena a family**: sin family_id -- codigo de invitacion self-hosted (no ligado a una family existente)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Usado en registro self-hosted (self_hosted_first_login? en Authentication concern).
- **Code paths de riesgo / a verificar**: Se busca por el codigo en texto plano/hash durante registro, sin ningun contexto de usuario o family todavia. SIN RLS (correcto, no hay family que aplicar).

### `oauth_access_grants` (OauthAccessGrant)
- **Clasificacion**: auth
- **Cadena a family**: oauth_access_grants.resource_owner_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Doorkeeper.
- **Code paths de riesgo / a verificar**: Se busca por `token` en el intercambio OAuth, sin family context.

### `oauth_access_tokens` (OauthAccessToken)
- **Clasificacion**: auth
- **Cadena a family**: oauth_access_tokens.resource_owner_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Doorkeeper; tambien mobile_device_id.
- **Code paths de riesgo / a verificar**: Se busca por token/hash en CADA request autenticado via OAuth (API movil) -- este es el mecanismo equivalente a Session para clientes OAuth. Confirmar si api/v1/base_controller soporta auth via OAuth token ademas de session cookie, y si RlsContext.set_family corre igual de temprano/tarde en ese path.

### `oauth_applications` (OauthApplication)
- **Clasificacion**: auth
- **Cadena a family**: oauth_applications.owner_id/type (polymorphic, probablemente User o admin)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Doorkeeper OAuth provider (FinancePY como servidor OAuth para su propia app movil / integraciones).
- **Code paths de riesgo / a verificar**: SIN RLS; tabla de configuracion, no de datos de usuario final.

### `oidc_identities` (OidcIdentity)
- **Clasificacion**: auth
- **Cadena a family**: oidc_identities.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: SSO (OIDC) identity linking.
- **Code paths de riesgo / a verificar**: Se busca por (issuer, subject claim) en el callback SSO, antes de conocer la family.

### `sessions` (Session)
- **Clasificacion**: auth
- **Cadena a family**: sessions.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Sesiones son EL mecanismo de bootstrap del family context.
- **Code paths de riesgo / a verificar**: find_session_by_cookie hace `Session.find_by(id: cookie_value)` sin ningun scoping -- por diseno (es lo que establece quien es el usuario). SIN RLS, correcto.

### `sso_audit_logs` (SsoAuditLog)
- **Clasificacion**: auth
- **Cadena a family**: sso_audit_logs.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Audit trail de eventos SSO.
- **Code paths de riesgo / a verificar**: SIN RLS; log de seguridad -- normalmente estos SI deberian ser legibles solo por super_admin, no por la family del user, asi que 'ninguna RLS' podria ser intencional (se protege a nivel controller/admin, no a nivel family).

### `sso_providers` (SsoProvider)
- **Clasificacion**: auth
- **Cadena a family**: sin family_id -- configuracion de proveedor SSO (client_id, client_secret encriptado)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Gestionado desde admin/sso_providers_controller.rb (super_admin panel).
- **Code paths de riesgo / a verificar**: Si es config global (no vi columna family_id) entonces es platform-wide; si el admin panel de families tambien la edita, confirmar que no se filtra por family incorrectamente. SIN RLS.

### `users` (User)
- **Clasificacion**: auth
- **Cadena a family**: users.family_id (propio, pero la tabla se consulta ANTES de conocer la family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Raiz de identidad; Session#user, find_by(email:) en login, etc.
- **Code paths de riesgo / a verificar**: authenticate_user! busca Session por cookie ANTES de setear RlsContext (ver app/controllers/concerns/authentication.rb linea 19-22); el User se resuelve via session.user en ese mismo momento pre-context. users no tiene RLS (no esta en la lista de 23) -- correcto, no podria tenerla dado este orden de bootstrap.

### `webauthn_credentials` (WebauthnCredential)
- **Clasificacion**: auth
- **Cadena a family**: webauthn_credentials.user_id -> users.family_id
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Passkeys.
- **Code paths de riesgo / a verificar**: Se busca por credential_id en el flujo de login WebAuthn, antes de family context (analogo a Session).

### `ar_internal_metadata` (ActiveRecord::InternalMetadata)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Rails framework.

### `eval_datasets` (Eval::Dataset)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Datasets internos para evaluar calidad del asistente IA (no ligados a family real).

### `eval_results` (Eval::Result)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: eval_run_id/eval_sample_id.

### `eval_runs` (Eval::Run)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: eval_dataset_id -> eval_datasets.

### `eval_samples` (Eval::Sample)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: eval_dataset_id -> eval_datasets.

### `exchange_rate_pairs` (ExchangeRatePair)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Pares de monedas soportados, catalogo global.

### `exchange_rates` (ExchangeRate)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Tasas de cambio historicas, genuinamente globales.

### `platform_daily_metrics` (PlatformDailyMetric)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Metricas agregadas de toda la plataforma (para super_admin dashboard), cross-family por definicion.

### `schema_migrations` (SchemaMigration)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Rails framework, migraciones aplicadas.

### `securities` (Security)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Catalogo global de valores (tickers, ISIN, etc).

### `security_prices` (SecurityPrice)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Precios historicos, security_id -> securities.

### `settings` (Setting)
- **Clasificacion**: global
- **Cadena a family**: N/A (genuinamente global, sin relacion a family)
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: RailsSettings::Base; config global de la instancia (self-hosting), singleton key-value, no tabla por-family.

### `active_storage_attachments` (ActiveStorage::Attachment)
- **Clasificacion**: storage
- **Cadena a family**: active_storage_attachments.record_id/type -> polymorphic (Account#logo, FamilyDocument, ArchivedExport#export_file, etc) -> family via el record
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Rails Active Storage; no tiene columna family propia por diseno (framework table).
- **Code paths de riesgo / a verificar**: Descarga por signed Active Storage id: el signed id en si mismo NO valida ownership de family -- cualquiera con el signed id de un blob puede pedirlo via las rutas estandar de ActiveStorage (/rails/active_storage/blobs/:signed_id/*) salvo que la app override esas rutas con un controller propio que revalide Current.family. Confirmar si existe tal override (no se encontro uno explicito en app/controllers en esta pasada) -- riesgo ALTO a verificar en la siguiente etapa.

### `active_storage_blobs` (ActiveStorage::Blob)
- **Clasificacion**: storage
- **Cadena a family**: active_storage_attachments.record_id/type -> polymorphic (Account#logo, FamilyDocument, ArchivedExport#export_file, etc) -> family via el record
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Rails Active Storage; no tiene columna family propia por diseno (framework table).
- **Code paths de riesgo / a verificar**: Descarga por signed Active Storage id: el signed id en si mismo NO valida ownership de family -- cualquiera con el signed id de un blob puede pedirlo via las rutas estandar de ActiveStorage (/rails/active_storage/blobs/:signed_id/*) salvo que la app override esas rutas con un controller propio que revalide Current.family. Confirmar si existe tal override (no se encontro uno explicito en app/controllers en esta pasada) -- riesgo ALTO a verificar en la siguiente etapa.

### `active_storage_variant_records` (ActiveStorage::VariantRecord)
- **Clasificacion**: storage
- **Cadena a family**: active_storage_attachments.record_id/type -> polymorphic (Account#logo, FamilyDocument, ArchivedExport#export_file, etc) -> family via el record
- **Policy RLS**: ninguna
- **FORCE**: no
- **Notas**: Rails Active Storage; no tiene columna family propia por diseno (framework table).
- **Code paths de riesgo / a verificar**: Descarga por signed Active Storage id: el signed id en si mismo NO valida ownership de family -- cualquiera con el signed id de un blob puede pedirlo via las rutas estandar de ActiveStorage (/rails/active_storage/blobs/:signed_id/*) salvo que la app override esas rutas con un controller propio que revalide Current.family. Confirmar si existe tal override (no se encontro uno explicito en app/controllers en esta pasada) -- riesgo ALTO a verificar en la siguiente etapa.

## Que NO esta cubierto en esta etapa

- **Rake tasks** (`lib/tasks/*.rake`): no se grep-earon exhaustivamente por `ActiveRecord::Base.connection.execute`,
  `unscoped`, `find_by_sql` o escrituras masivas sin family context. Pendiente.
- **Mailers** (`app/mailers/*.rb`): no se revisaron en detalle; los nombres (`demo_family_refresh_mailer`,
  `invitation_mailer`, `impersonation_mailer`, `password_mailer`, `email_confirmation_mailer`, `pdf_import_mailer`)
  sugieren que la mayoria corre dentro de un job/request que ya tiene family context, pero no se confirmo linea por
  linea.
- **Los ~10 procesadores de webhook/provider distintos de Plaid** (SimpleFin, Coinbase, Coinstats, EnableBanking,
  IndexaCapital, Lunchflow, Mercury, Snaptrade, Sophtron, Binance): se asume el mismo patron de PlaidItem::WebhookProcessor
  (find sin RLS + encolar job que si setea RlsContext) por analogia de codigo (misma estructura Item/Account observada en
  `db/structure.sql` y en los modelos), pero no se abrio cada `webhook_processor.rb` individualmente.
- **`admin/*_controller.rb`**: no se audito si la autorizacion `super_admin?` es consistente en los 5 controllers
  (`base_controller.rb`, `families_controller.rb`, `invitations_controller.rb`, `sso_providers_controller.rb`,
  `users_controller.rb`). Eso es autorizacion de aplicacion, no RLS -- mencionado por completitud, no por scope.
- **Rutas de Active Storage** (`config/routes.rb`): se senala como riesgo ALTO (ver hallazgo 8) pero no se confirmo si
  existe o no un controller custom que las proteja -- se recomienda verificar explicitamente antes de la siguiente etapa.
- **`insert_all`/`upsert_all` en bulk imports** (`Import`, `StatementImport`, sync processors de cada provider): no se
  grep-earon todos los usos de `insert_all!`/`upsert_all` uno por uno para confirmar que corren dentro de un bloque
  `RlsContext.with_family`. Los que se revisaron (jobs con `ActiveJobRowLevelSecurity`) estan cubiertos por el concern a
  nivel de job completo, lo cual cubre estos casos siempre que el import corra como ActiveJob (parece ser el caso
  general, pero no 100% confirmado para cada importer).
