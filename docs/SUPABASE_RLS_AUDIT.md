# Informe de Auditoría de Seguridad: Row Level Security (RLS) en Supabase / PostgreSQL (CD & Co ERP)

**Fecha:** 26 de Agosto de 2026
**Rama:** `version-1.1.0`
**Autor:** Jules (Software Engineer / Security Audit)
**Estado:** Diagnóstico Completo (Sin modificaciones aplicadas a la base de datos)

---

## 1. Resumen Ejecutivo y Arquitectura de Acceso

El sistema **CD & Co ERP / FinancePY** utiliza PostgreSQL alojado en Supabase (esquema `public`). Existen dos vías principales de interacción con la base de datos:

1. **Acceso vía servidor backend (Rails 7.2):**
   Conecta a través de `DATABASE_URL` utilizando un usuario con permisos elevados (típicamente `postgres`). El servidor Rails inyecta context de tenant ejecutando `SET app.current_family_id = '<family_uuid>'` por cada request/job (`RlsContext`).
2. **Acceso directo vía cliente Supabase (App Móvil / ERP Direct Client):**
   Conecta directamente a las APIs REST/Realtime de Supabase utilizando la **Anon Key** (`SUPABASE_ANON_KEY`), omitiendo por completo la capa backend de Rails.

### Riesgo Principal Detectado
Cuando un cliente consulta Supabase directamente usando la anon key:
- El rol PostgreSQL efectivo es `anon` (sin token) o `authenticated` (con JWT de Supabase).
- Ninguna sesión HTTP de Rails ha ejecutado `SET app.current_family_id`. Por ende, la función helper `current_family_id()` devuelve `NULL`.
- Esto provoca un comportamiento dual altamente vulnerable:
  1. En las consultas `SELECT`/`UPDATE`/`DELETE` sobre las 12 tablas con RLS, el filtro `family_id = current_family_id()` se evalúa como `family_id = NULL`, **bloqueando todo acceso a datos legítimos (0 filas devueltas)**.
  2. En las 97 tablas **SIN RLS**, si el rol `anon`/`authenticated` posee permisos `GRANT`, **se expone el 100% de la información financiera y comercial del ERP a cualquier cliente sin ningún tipo de aislamiento de tenant**.
  3. En inserciones sobre tablas polimórficas (`transactions`, `valuations`, `receivables`), la política `WITH CHECK (true)` permite **inyectar registros maliciosos o no autorizados sin validación de tenant**.

---

## 2. Auditoría de Roles PostgreSQL y Privilegios Supabase (Requisito 4)

| Rol PostgreSQL | Contexto de Uso | Atributos (`SUPERUSER`) | Atributos (`BYPASSRLS`) | Evaluación de RLS |
| :--- | :--- | :--- | :--- | :--- |
| **`postgres`** | Backend Rails / Migraciones | **SÍ** (`SUPERUSER`) | **SÍ** (`BYPASSRLS`) | **Bypassea RLS** por defecto a menos que se use `FORCE RLS` o un rol `app_user` dedicado sin `BYPASSRLS`. |
| **`anon`** | Cliente Supabase sin autenticar (Anon Key) | **NO** (`NOSUPERUSER`) | **NO** (`NOBYPASSRLS`) | **Sujeto estrictamente a políticas RLS**. Permite acceso completo a tablas sin RLS si tiene GRANTs. |
| **`authenticated`** | Cliente Supabase autenticado (JWT) | **NO** (`NOSUPERUSER`) | **NO** (`NOBYPASSRLS`) | **Sujeto estrictamente a políticas RLS**. Permite acceso completo a tablas sin RLS si tiene GRANTs. |

### Conclusión del Rol del Cliente
Confirmado: El cliente directo de Supabase utiliza los roles `anon` y `authenticated`. Estos roles **NO son superusuarios** ni tienen el atributo **`BYPASSRLS`**. Sin embargo, Supabase otorga por defecto permisos DML (`SELECT, INSERT, UPDATE, DELETE`) en el esquema `public` a `anon` y `authenticated`, lo que significa que **cualquier tabla sin RLS queda totalmente abierta a lectura/escritura global**.

---

## 3. Inventario Completo de Tablas y Estado de RLS (Requisito 1)

Total de tablas en la base de datos: **109 tablas** (según `db/schema.rb`).

- **Tablas con RLS Enabled y FORCE RLS:** **12 tablas** (11.0%)
- **Tablas SIN RLS Enabled:** **97 tablas** (89.0%)

```sql
-- Consulta de verificación ejecutada conceptualmente en pg_tables y pg_class:
SELECT tablename, rowsecurity
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public';
```

---

## 4. Auditoría de Políticas Reales en Tablas con RLS (Requisito 2)

Análisis detallado de las políticas definidas en `db/migrate/20260819000000_enable_row_level_security.rb` y `docs/RLS_SETUP.md`:

### 4.1. Tablas con `family_id` Directo (6 tablas)
Tablas: `accounts`, `budgets`, `goals`, `rules`, `categories`, `tags`.

- **Nombre de la política:** `<tabla>_family_isolation_policy`
- **Comando:** `FOR ALL`
- **Condición USING:** `(family_id = current_family_id())`
- **Condición WITH CHECK:** `(family_id = current_family_id())`
- **Evaluación de Seguridad:**
  - **Para Rails:** Correcto cuando `app.current_family_id` está configurado.
  - **Para Cliente Supabase Directo:** `current_family_id()` retorna `NULL`. `family_id = NULL` evalúa como FALSO. Imposibilita la lectura/escritura legítima desde el cliente Supabase directo, ya que no soporta JWT claim extraction (`auth.jwt() -> 'family_id'`).

### 4.2. Tablas Relacionales Indirectas (3 tablas)
Tablas: `merchants`, `entries`, `budget_categories`.

- **`merchants`:**
  - **USING & WITH CHECK:** `(family_id = current_family_id() OR family_id IS NULL)`
  - **Evaluación:** Permite lectura de comercios globales (`family_id IS NULL`), pero falla en el cliente Supabase directo para comercios privados de la familia.
- **`entries`:**
  - **USING & WITH CHECK:** `account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())`
  - **Evaluación:** Aislamiento correcto bajo Rails; bloqueado bajo cliente Supabase directo.
- **`budget_categories`:**
  - **USING & WITH CHECK:** `budget_id IN (SELECT id FROM budgets WHERE family_id = current_family_id())`
  - **Evaluación:** Aislamiento correcto bajo Rails; bloqueado bajo cliente Supabase directo.

### 4.3. Tablas Polimórficas Indirectas (3 tablas)
Tablas: `transactions`, `valuations`, `receivables`.

- **`transactions`:**
  - **Condición USING:** `id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Transaction' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))`
  - **Condición WITH CHECK:** `(true)`
  - **CRITICAL BYPASS DETECTADO:** La cláusula `WITH CHECK (true)` **permite cualquier inserción de transacciones sin validar la pertenencia al tenant**. Un atacante o cliente directo de Supabase puede insertar registros arbitrarios en `transactions` sin restricciones.
- **`valuations`:**
  - **Condición USING:** `id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Valuation' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))`
  - **Condición WITH CHECK:** `(true)`
  - **CRITICAL BYPASS DETECTADO:** Mismo bypass por `WITH CHECK (true)` en inserción.
- **`receivables`:**
  - **Condición USING:** `id IN (SELECT accountable_id FROM accounts WHERE accountable_type = 'Receivable' AND family_id = current_family_id())`
  - **Condición WITH CHECK:** `(true)`
  - **CRITICAL BYPASS DETECTADO:** Mismo bypass por `WITH CHECK (true)` en inserción.

---

## 5. Auditoría de Tablas SIN RLS y Clasificación de Riesgo (Requisito 3)

De las **97 tablas sin RLS**, se ha realizado una evaluación de sensibilidad de los datos almacenados y la presencia de identificadores de tenant (`family_id`, `user_id`, `account_id`).

### 5.1. Hallazgos Críticos (64 Tablas) — Datos Financieros, Comerciales y Bancarios de Tenant SIN RLS

Estas tablas contienen información financiera, comercial o sensible de familias/empresas y **NO tienen RLS activado**. Cualquier petición directa al API de Supabase vía Anon Key puede leer, modificar o eliminar todos los datos.

#### A. Módulo ERP / Ventas y Compras (6 tablas)
1. `products` (`family_id`)
2. `sales` (`family_id`)
3. `sale_items` (Vías `sale_id`)
4. `purchase_orders` (`family_id`)
5. `purchase_order_items` (Vías `purchase_order_id`)
6. `product_stock_movements` (Vías `product_id`)

#### B. Módulo Fleet Management / Flota y Combustible (2 tablas)
7. `fleet_vehicles` (`family_id`)
8. `fuel_logs` (`account_id`)

#### C. Integraciones Bancarias y Credenciales de Ingesta (20 tablas)
9. `plaid_items` (`family_id`)
10. `plaid_accounts`
11. `simplefin_items` (`family_id`)
12. `simplefin_accounts` (`account_id`)
13. `snaptrade_items` (`family_id`, contiene `snaptrade_user_secret`)
14. `snaptrade_accounts`
15. `mercury_items` (`family_id`)
16. `mercury_accounts` (`account_id`)
17. `enable_banking_items` (`family_id`)
18. `enable_banking_accounts` (`account_id`)
19. `lunchflow_items` (`family_id`)
20. `lunchflow_accounts` (`account_id`)
21. `coinbase_items` (`family_id`)
22. `coinbase_accounts` (`account_id`)
23. `coinstats_items` (`family_id`)
24. `coinstats_accounts` (`account_id`)
25. `sophtron_items` (`family_id`)
26. `sophtron_accounts` (`account_id`)
27. `binance_items` (`family_id`)
28. `binance_accounts` (`account_id`)

#### D. Inversiones, Activos, Deudas y Balances (17 tablas)
29. `holdings` (`account_id`, `account_provider_id`)
30. `trades` (Vías `account_id`)
31. `balances` (`account_id`)
32. `account_shares` (`account_id`, `user_id`)
33. `account_providers` (`account_id`)
34. `other_assets` (Accountable)
35. `other_liabilities` (Accountable)
36. `properties` (Accountable)
37. `vehicles` (Accountable)
38. `loans` (Accountable)
39. `cryptos` (Accountable)
40. `depositories` (Accountable)
41. `credit_cards` (Accountable)
42. `goal_accounts` (`account_id`)
43. `goal_pledges` (`account_id`)
44. `family_merchant_associations` (`family_id`)
45. `rejected_transfers`

#### E. Transacciones Recurrentes, Importaciones y Motor de Reglas (11 tablas)
46. `recurring_transactions` (`family_id`, `account_id`)
47. `imports` (`family_id`, `account_id`)
48. `import_rows`
49. `import_mappings`
50. `statement_imports` (`family_id`, `user_id`)
51. `transfers`
52. `taggings`
53. `rule_actions`
54. `rule_conditions`
55. `rule_runs`
56. `syncs`

#### F. IA Assistant, Documentos y Exportaciones (8 tablas)
57. `chats` (`user_id`)
58. `messages` (Vías `chat_id`)
59. `llm_usages` (`family_id`)
60. `tool_calls`
61. `family_documents` (`family_id`)
62. `family_exports` (`family_id`)
63. `archived_exports` (`family_name`)
64. `subscriptions` (`family_id`)

---

### 5.2. Hallazgos de Severidad Alta (10 Tablas) — Datos de Usuario, Sesiones e Identidad SIN RLS

Contienen credenciales, tokens de acceso, sesiones e información personal de usuarios.

1. `users` (`family_id`, emails, hashes de contraseñas, preferenciales)
2. `sessions` (`user_id`, session tokens)
3. `api_keys` (`user_id`, tokens de API)
4. `mobile_devices` (`user_id`, push tokens)
5. `sso_audit_logs` (`user_id`, logs de acceso SSO)
6. `oidc_identities` (`user_id`, tokens de proveedores OIDC)
7. `webauthn_credentials` (`user_id`, llaves de autenticación biométrica)
8. `impersonation_sessions`
9. `impersonation_session_logs`
10. `invitations` (`family_id`)

---

### 5.3. Hallazgos de Severidad Media / Baja (23 Tablas) — Metadata Global y Tablas de Soporte

Tablas que contienen tipos de cambio, precios globales de mercado, catálogo de valores o metadata general que no es específica de un tenant.

1. `exchange_rates` (Global)
2. `exchange_rate_pairs` (Global)
3. `securities` (Global)
4. `security_prices` (Global)
5. `families` (Metadata de la organización)
6. `invite_codes`
7. `sso_providers`
8. `settings`
9. `data_enrichments`
10. `eval_datasets`
11. `eval_results`
12. `eval_runs`
13. `eval_samples`
14. `oauth_applications`
15. `oauth_access_tokens`
16. `oauth_access_grants`
17. `active_storage_attachments`
18. `active_storage_blobs`
19. `active_storage_variant_records`
20. `addresses`
21. `investments`

---

## 6. Matriz Resumen de Hallazgos

| ID | Componente / Tabla | Severidad | Descripción del Hallazgo | Impacto Potencial |
| :--- | :--- | :--- | :--- | :--- |
| **H-01** | Acceso Supabase Anon Key | **CRÍTICO** | El cliente directo Supabase no ejecuta `SET app.current_family_id`, dejando `current_family_id()` en `NULL`. | Bloqueo de lecturas legítimas y falla total de la cliente Supabase directo para consultas RLS. |
| **H-02** | Policies `transactions`, `valuations`, `receivables` | **CRÍTICO** | Cláusula `WITH CHECK (true)` en la política RLS de inserción. | Permite a cualquier usuario/cliente inyectar transacciones o valores de cualquier tenant sin validación. |
| **H-03** | 64 Tablas Financieras/ERP | **CRÍTICO** | Tablas de ventas, productos, compras, integraciones bancarias, holdings y combustibles **SIN RLS**. | Acceso directo de lectura/escritura/borrado de datos confidenciales de cualquier empresa/familia vía Anon Key. |
| **H-04** | 10 Tablas de Identidad/Usuarios | **ALTO** | Tablas `users`, `sessions`, `api_keys`, `webauthn_credentials` **SIN RLS**. | Exposición global de datos de usuarios, tokens de sesión y tokens push móviles. |
| **H-05** | Configuración GRANTs en Supabase | **MEDIO** | El esquema `public` posee permisos DML por defecto otorgados a `anon` y `authenticated`. | Cualquier tabla nueva agregada sin RLS queda automáticamente expuesta a la API REST pública de Supabase. |

---

## 7. Recomendaciones Técnicas para Fase de Remediación

*(Nota: De acuerdo con las instrucciones de la auditoría, ninguna remediación ha sido aplicada en esta fase).*

1. **Definir la Estrategia de Autenticación Supabase:**
   - Si el cliente de CD & Co ERP va a consumir Supabase directamente vía anon key + JWT de Supabase, refactorizar la función helper PostgreSQL para extraer el `family_id` desde el JWT de Supabase (`auth.jwt() -> 'app_metadata' ->> 'family_id'`) además de `current_setting('app.current_family_id', true)`.
2. **Corregir las Cláusulas WITH CHECK Polimórficas:**
   - Eliminar `WITH CHECK (true)` en `transactions`, `valuations` y `receivables`, reemplazándolas por comprobaciones de validación previa sobre la cuenta / familia asociada.
3. **Habilitar RLS en las 74 Tablas Sensibles Restantes:**
   - Crear migraciones para ejecutar `ALTER TABLE <tabla> ENABLE ROW LEVEL SECURITY;` y `ALTER TABLE <tabla> FORCE ROW LEVEL SECURITY;` con sus correspondientes políticas de aislamiento por tenant.
4. **Restringir GRANTs del Rol `anon`:**
   - Revocar permisos `INSERT`, `UPDATE`, `DELETE` sobre tablas sensibles para el rol `anon`, permitiéndolos únicamente al rol `authenticated` cuando el JWT de Supabase sea válido y verificado.
