-- ============================================================
-- Auto-provision: nuevo signup => org + profile + pipeline default
-- Aplicar DESPUÉS de schema.sql en Supabase SQL Editor
-- ============================================================

create or replace function handle_new_user() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id   uuid;
  v_org_name text;
  v_slug     text;
begin
  v_org_name := coalesce(
    new.raw_user_meta_data->>'org_name',
    split_part(new.email, '@', 1) || ' workspace'
  );
  v_slug := lower(regexp_replace(v_org_name, '[^a-zA-Z0-9]+', '-', 'g'))
            || '-' || substr(new.id::text, 1, 8);

  insert into organizations(name, slug) values (v_org_name, v_slug) returning id into v_org_id;

  insert into profiles(id, org_id, full_name, role) values (
    new.id,
    v_org_id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    'owner'
  );

  perform seed_default_pipeline(v_org_id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
