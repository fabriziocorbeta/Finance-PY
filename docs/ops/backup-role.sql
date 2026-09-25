-- Rol de respaldo sin superusuario para bin/backup_encrypted.sh
--
-- Hoy ese script usa LOCAL_ADMIN_DATABASE_URL (rol admin/superusuario) para
-- pg_dump -- un superusuario tiene alcance total sobre la instancia
-- (crear/borrar roles, leer pg_authid, bypass de TODO), mucho más de lo que
-- un backup necesita. Este script crea `financespy_backup`: puede LEER
-- todas las tablas (incluidas las 24 con RLS FORCE) pero no puede escribir,
-- no puede crear roles, no es superusuario.
--
-- *** Tradeoff importante, verificado contra el modelo RLS real del repo ***
-- (app/models/concerns/rls_context.rb, ver contexto de la tarea): el rol
-- predefinido `pg_read_all_data` (Postgres 14+) da SELECT en todas las
-- tablas de todos los esquemas, PERO NO bypassea Row Level Security. Con
-- FORCE ROW LEVEL SECURITY activo en 24 tablas (accounts, transactions,
-- entries, etc. -- ver contexto de la tarea) y sin el GUC
-- `app.current_family_id` seteado (pg_dump no lo setea), un dump con SOLO
-- pg_read_all_data devolvería 0 filas de esas 24 tablas: un backup
-- "completo" que en realidad no lo es, y nadie se entera hasta que hace
-- falta restaurar.
--
-- Por eso este rol también lleva BYPASSRLS explícito. BYPASSRLS es un
-- atributo de rol independiente de SUPERUSER (se puede tener uno sin el
-- otro) -- sigue sin ser superusuario, sigue sin poder crear/alterar roles
-- ni tocar catálogos protegidos, pero sí ve todas las filas sin el contexto
-- RLS. Si en algún momento se prefiere NO bypassear RLS ni siquiera para
-- backups, la alternativa es que el script de backup haga
-- `SET app.current_family_id = ...` por cada una de las 2 familias reales
-- de prod y dumpee por separado -- más pasos, pero sin BYPASSRLS. Se dejó
-- BYPASSRLS acá porque un solo backup completo y simple es más confiable
-- operacionalmente que N backups parciales encadenados.
--
-- Uso (contra la base real, como superusuario -- una sola vez, o cada vez
-- que se corre este script no hace nada si el rol ya existe con estos
-- atributos, ver los DO blocks):
--   psql "$SUPERUSER_DATABASE_URL" -v backup_role_password="'<password generado>'" -f docs/ops/backup-role.sql
--
-- Generar el password con: openssl rand -hex 32

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'financespy_backup') THEN
    CREATE ROLE financespy_backup WITH
      LOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      NOREPLICATION
      BYPASSRLS
      CONNECTION LIMIT 2;
  ELSE
    -- Rol ya existe (re-ejecución idempotente): normalizar atributos por si
    -- alguien lo tocó a mano, sin recrearlo (evita invalidar el password ya
    -- seteado si no hace falta cambiarlo).
    ALTER ROLE financespy_backup WITH
      LOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      NOREPLICATION
      BYPASSRLS
      CONNECTION LIMIT 2;
  END IF;
END
$$;

-- Password separado del CREATE/ALTER de arriba para poder reemplazarlo sin
-- tocar el resto (rotación de credencial). Requiere pasar -v
-- backup_role_password="'...'" (con comillas simples adentro, ver Uso arriba).
ALTER ROLE financespy_backup WITH PASSWORD :backup_role_password;

-- pg_read_all_data: SELECT en todas las tablas actuales de todos los
-- esquemas (financespy, extensions, public). No hace falta re-otorgar tras
-- crear tablas nuevas -- es un rol, no un GRANT por tabla, así que cubre
-- tablas futuras automáticamente.
GRANT pg_read_all_data TO financespy_backup;

-- USAGE explícito sobre el esquema financespy (search_path del proyecto,
-- ver contexto de la tarea) por si algún cliente de backup no hereda
-- search_path del rol y necesita el esquema calificado a mano.
GRANT USAGE ON SCHEMA financespy TO financespy_backup;

-- No hace falta GRANT sobre pgcrypto (esquema extensions): pg_dump con
-- --schema=financespy (como ya usa bin/backup_encrypted.sh) no toca
-- extensions, y pg_read_all_data no incluye EXECUTE en funciones de
-- extensiones de todos modos (fuera de scope de un backup).
