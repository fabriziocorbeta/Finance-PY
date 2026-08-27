# Configuración y Despliegue de Row Level Security (RLS) en Postgres

Este documento detalla la arquitectura de Row Level Security (RLS) implementada como una segunda capa de defensa a nivel de base de datos para la aplicación **FinancePY** (Rails 7.2 + Postgres / Supabase).

---

## 1. Análisis del Usuario Postgres y BYPASSRLS

### Hallazgo en Entornos de Producción / Supabase
En entornos de producción (especialmente en **Supabase** o instancias administradas de PostgreSQL), el usuario predeterminado configurado en `config/database.yml` vía la variable de entorno `POSTGRES_USER` suele ser el rol predeterminado de administración (ej. `postgres` o `authenticated_admin`).

Por defecto en PostgreSQL:
- Los usuarios con el atributo **`SUPERUSER`** o **`BYPASSRLS`** ignoran por completo todas las políticas de Row Level Security.
- En Supabase, el usuario `postgres` es superusuario/BYPASSRLS por defecto.

### Requisito Crítico para Producción
Para que las políticas RLS tengan efecto real y bloqueen efectivamente accesos no autorizados entre tenants:
1. **NO usar un superusuario ni un usuario con `BYPASSRLS`** para las conexiones estándar de la aplicación Rails.
2. Crear un rol de base de datos dedicado para la aplicación sin privilegios `SUPERUSER` ni `BYPASSRLS` (ejemplo: `app_user`).
3. Asignar la propiedad de las tablas a un rol migrador (`migrator_role`) o superusuario, y otorgar permisos DML (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) al rol `app_user`.

#### Script SQL para Configurar el Rol de Aplicación sin BYPASSRLS
```sql
-- 1. Crear el rol dedicado para la app Rails (sin superusuario ni bypassrls)
CREATE ROLE app_user WITH LOGIN PASSWORD :'app_user_password' NOBYPASSRLS NOSUPERUSER; -- pasar con psql -v app_user_password=... , nunca hardcodear el valor real acá

-- 2. Conceder permisos necesarios en el esquema financespy
-- NOTA: produccion usa el schema "financespy", no "public" (confirmado via
-- docker inspect del contenedor y compose.local.yml). Ajustar antes de correr.
GRANT USAGE ON SCHEMA financespy TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA financespy TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA financespy TO app_user;

-- 3. Asegurar permisos por defecto para futuras migraciones
ALTER DEFAULT PRIVILEGES IN SCHEMA financespy GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA financespy GRANT USAGE, SELECT ON SEQUENCES TO app_user;
```

Posteriormente, actualizar la variable de entorno `POSTGRES_USER=app_user` (y su contraseña respectiva) en el servidor de producción.

---

## 2. Estrategia de Despliegue sin Tiempo de Inactividad (Zero Downtime)

Para aplicar RLS en producción en una base de datos activa con usuarios conectados sin causar caídas ni interrupciones del servicio, se recomienda seguir el siguiente orden secuencial de pasos.

### Paso 1: Crear la función PostgreSQL helper
Aplicar la migración o ejecutar directamente el script para crear la función `current_family_id()`:

```sql
CREATE OR REPLACE FUNCTION current_family_id() RETURNS uuid AS $$
BEGIN
  RETURN NULLIF(current_setting('app.current_family_id', true), '')::uuid;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;
```

### Paso 2: Habilitar RLS en Modo Permisivo y Validación con Logging
Antes de bloquear consultas no coincidentes, podés validar la coincidencia en logs para identificar cualquier consulta de HTTP request, background job (ActiveJob / Sidekiq workers, sync bancarios, recurring transactions, materialización de balances) o rake task que no esté enviando el context `app.current_family_id`. Durante la fase permisiva de rollout, monitoreá activamente las siguientes fuentes de consultas:
- HTTP Requests (vía `ApplicationController`)
- ActiveJob / Sidekiq background workers (vía `ActiveJobRowLevelSecurity`)
- Tareas cron / scheduled jobs globales (vía loops por family con `RlsContext.with_family`)

Se habilita RLS en las tablas objetivo:
```sql
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE valuations ENABLE ROW LEVEL SECURITY;
ALTER TABLE receivables ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
```

### Paso 3: Aplicar las Políticas RLS
Crear las políticas RLS asociadas a cada tabla. Nota: Para las tablas polimórficas e indirectas (`transactions`, `valuations`, `receivables`), se utiliza `WITH CHECK (true)` en inserción para permitir crear el registro maestro antes de asociarle su `Entry` o `Account` correspondiente:

```sql
-- Tablas con family_id directo
CREATE POLICY accounts_family_isolation_policy ON accounts FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());
CREATE POLICY budgets_family_isolation_policy ON budgets FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());
CREATE POLICY goals_family_isolation_policy ON goals FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());
CREATE POLICY rules_family_isolation_policy ON rules FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());
CREATE POLICY categories_family_isolation_policy ON categories FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());
CREATE POLICY tags_family_isolation_policy ON tags FOR ALL USING (family_id = current_family_id()) WITH CHECK (family_id = current_family_id());

-- Merchants (merchants compartidos globalmente tienen family_id NULL)
CREATE POLICY merchants_family_isolation_policy ON merchants FOR ALL USING (family_id = current_family_id() OR family_id IS NULL) WITH CHECK (family_id = current_family_id() OR family_id IS NULL);

-- Tablas relacionales indirectas
CREATE POLICY entries_family_isolation_policy ON entries FOR ALL USING (account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())) WITH CHECK (account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()));
CREATE POLICY budget_categories_family_isolation_policy ON budget_categories FOR ALL USING (budget_id IN (SELECT id FROM budgets WHERE family_id = current_family_id())) WITH CHECK (budget_id IN (SELECT id FROM budgets WHERE family_id = current_family_id()));

-- Tablas polimórficas indirectas (USING restringe lectura/modificación/eliminación, WITH CHECK (true) permite inserción previa al enlace)
CREATE POLICY transactions_family_isolation_policy ON transactions FOR ALL USING (id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Transaction' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))) WITH CHECK (true);
CREATE POLICY valuations_family_isolation_policy ON valuations FOR ALL USING (id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Valuation' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))) WITH CHECK (true);
CREATE POLICY receivables_family_isolation_policy ON receivables FOR ALL USING (id IN (SELECT accountable_id FROM accounts WHERE accountable_type = 'Receivable' AND family_id = current_family_id())) WITH CHECK (true);
```

### Paso 4: Desplegar la Aplicación Rails
Desplegar la versión del código que incluye:
1. El concern `RowLevelSecurity` en `ApplicationController` para HTTP requests.
2. El concern `ActiveJobRowLevelSecurity` en `ApplicationJob` para background workers (vía `around_perform`).

Cada petición HTTP y ejecución de background job establecerá:
```sql
SET app.current_family_id = '<family_id_uuid>';
```
al procesar requests o realizar tareas en background.

### Paso 5: Activar FORCE ROW LEVEL SECURITY (Obligatorio)
Por defecto en Postgres, el dueño de una tabla (table owner) ignora las políticas RLS aunque `ENABLE ROW LEVEL SECURITY` esté activo. Para forzar que incluso el usuario dueño de las tablas cumpla con RLS (en caso de no haber separado roles en el Paso 1):

```sql
ALTER TABLE accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE entries FORCE ROW LEVEL SECURITY;
ALTER TABLE transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE budgets FORCE ROW LEVEL SECURITY;
ALTER TABLE budget_categories FORCE ROW LEVEL SECURITY;
ALTER TABLE valuations FORCE ROW LEVEL SECURITY;
ALTER TABLE receivables FORCE ROW LEVEL SECURITY;
ALTER TABLE goals FORCE ROW LEVEL SECURITY;
ALTER TABLE rules FORCE ROW LEVEL SECURITY;
ALTER TABLE categories FORCE ROW LEVEL SECURITY;
ALTER TABLE merchants FORCE ROW LEVEL SECURITY;
ALTER TABLE tags FORCE ROW LEVEL SECURITY;
```

---

## 3. Verificación de Funcionamiento

Para verificar manualmente que RLS está bloqueando accesos cruzados a nivel de base de datos desde `psql` o un cliente SQL:

```sql
-- 1. Iniciar una transacción
BEGIN;

-- 2. Simular el contexto de una Family A
SET LOCAL app.current_family_id = '11111111-1111-1111-1111-111111111111';

-- 3. Intentar consultar accounts o transactions pertenecientes a Family B
SELECT * FROM accounts WHERE family_id = '22222222-2222-2222-2222-222222222222';
-- Resultado esperado: 0 filas devueltas (incluso si los registros existen en la base de datos).

COMMIT;
```

---

## 4. Tablas deliberadamente excluidas: `users` e `invitations`

`users` e `invitations` tienen `family_id`, pero NO reciben policy RLS a nivel de tabla. Es una decisión deliberada, no un gap pendiente:

- `users.email` tiene un índice único **global** (no scoped por family). El login (`SessionsController#create`, `User.find_by(email:)`) necesita encontrar al usuario ANTES de que exista contexto de family - en ese punto `current_family_id()` es `NULL`, así que una policy `family_id = current_family_id()` devolvería 0 filas siempre y ningún login funcionaría.
- `invitations` tiene el mismo problema para el flujo de aceptar invitación por token (el invitado todavía no tiene family propia en ese momento).
- La alternativa de agregar `OR current_family_id() IS NULL` a la policy anula la protección: cualquier contexto sin family seteada (incluyendo un job que se olvidó de setearlo) vería la tabla completa - exactamente el bug que RLS existe para prevenir.

El aislamiento entre families para estas dos tablas sigue siendo responsabilidad de la capa Rails (`family.users`, `family.invitations`), como ya es hoy. Si en el futuro se necesita RLS real acá, requiere un rol de DB separado con permiso explícito solo para el lookup de login/accept-invite, no el patrón `family_id = current_family_id()` que usan el resto de las tablas.
