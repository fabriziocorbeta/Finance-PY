-- ============================================================
-- CRM Social Hub — Schema Fase 1
-- Postgres / Supabase con RLS multi-tenant por org_id
-- ============================================================

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
-- ORGANIZATIONS (multi-tenant raíz)
-- ============================================================
create table if not exists organizations (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  slug        text unique not null,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- USERS (vinculado a auth.users de Supabase)
-- ============================================================
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  org_id      uuid not null references organizations(id) on delete cascade,
  full_name   text,
  avatar_url  text,
  role        text not null default 'member' check (role in ('owner','admin','member')),
  created_at  timestamptz not null default now()
);
create index on profiles(org_id);

-- ============================================================
-- CONTACTS
-- ============================================================
create table if not exists contacts (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null references organizations(id) on delete cascade,
  full_name     text not null,
  email         text,
  phone         text,
  whatsapp      text,
  instagram     text,
  facebook_id   text,
  company       text,
  position      text,
  source        text check (source in ('whatsapp','instagram','facebook','website','referral','manual','import','other')),
  status        text not null default 'lead' check (status in ('lead','prospect','customer','inactive')),
  notes         text,
  owner_id      uuid references profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on contacts(org_id);
create index on contacts(phone);
create index on contacts(email);
create index on contacts(status);

-- ============================================================
-- TAGS (etiquetas libres por contacto)
-- ============================================================
create table if not exists tags (
  id          uuid primary key default uuid_generate_v4(),
  org_id      uuid not null references organizations(id) on delete cascade,
  name        text not null,
  color       text not null default '#4F46E5',
  unique(org_id, name)
);

create table if not exists contact_tags (
  contact_id  uuid not null references contacts(id) on delete cascade,
  tag_id      uuid not null references tags(id) on delete cascade,
  primary key (contact_id, tag_id)
);

-- ============================================================
-- PIPELINES + STAGES
-- ============================================================
create table if not exists pipelines (
  id          uuid primary key default uuid_generate_v4(),
  org_id      uuid not null references organizations(id) on delete cascade,
  name        text not null,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);

create table if not exists stages (
  id            uuid primary key default uuid_generate_v4(),
  pipeline_id   uuid not null references pipelines(id) on delete cascade,
  name          text not null,
  position      int  not null,
  color         text not null default '#4F46E5',
  is_won        boolean not null default false,
  is_lost       boolean not null default false,
  created_at    timestamptz not null default now()
);
create index on stages(pipeline_id, position);

-- ============================================================
-- DEALS
-- ============================================================
create table if not exists deals (
  id              uuid primary key default uuid_generate_v4(),
  org_id          uuid not null references organizations(id) on delete cascade,
  contact_id      uuid not null references contacts(id) on delete cascade,
  pipeline_id     uuid not null references pipelines(id) on delete cascade,
  stage_id        uuid not null references stages(id) on delete restrict,
  title           text not null,
  value_cents     bigint not null default 0,
  currency        text not null default 'PYG',
  probability     int  not null default 0 check (probability between 0 and 100),
  expected_close  date,
  owner_id        uuid references profiles(id) on delete set null,
  position        int  not null default 0,
  status          text not null default 'open' check (status in ('open','won','lost')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  closed_at       timestamptz
);
create index on deals(org_id);
create index on deals(stage_id, position);
create index on deals(contact_id);

-- ============================================================
-- ACTIVITIES (timeline por contact/deal)
-- ============================================================
create table if not exists activities (
  id            uuid primary key default uuid_generate_v4(),
  org_id        uuid not null references organizations(id) on delete cascade,
  contact_id    uuid references contacts(id) on delete cascade,
  deal_id       uuid references deals(id) on delete cascade,
  user_id       uuid references profiles(id) on delete set null,
  kind          text not null check (kind in ('note','call','email','meeting','task','message','status_change','deal_moved')),
  title         text,
  body          text,
  due_at        timestamptz,
  completed_at  timestamptz,
  metadata      jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);
create index on activities(org_id);
create index on activities(contact_id, created_at desc);
create index on activities(deal_id, created_at desc);

-- ============================================================
-- updated_at triggers
-- ============================================================
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

drop trigger if exists trg_contacts_updated on contacts;
create trigger trg_contacts_updated before update on contacts
  for each row execute function set_updated_at();

drop trigger if exists trg_deals_updated on deals;
create trigger trg_deals_updated before update on deals
  for each row execute function set_updated_at();

-- ============================================================
-- RLS — todas las tablas org-scoped
-- ============================================================
alter table organizations enable row level security;
alter table profiles      enable row level security;
alter table contacts      enable row level security;
alter table tags          enable row level security;
alter table contact_tags  enable row level security;
alter table pipelines     enable row level security;
alter table stages        enable row level security;
alter table deals         enable row level security;
alter table activities    enable row level security;

-- helper: org_id del usuario actual
create or replace function current_org_id() returns uuid as $$
  select org_id from profiles where id = auth.uid() limit 1;
$$ language sql stable security definer;

-- Policies: usuario solo ve/edita filas de su org
create policy "org_members_read_org" on organizations
  for select using (id = current_org_id());

create policy "org_members_read_profiles" on profiles
  for select using (org_id = current_org_id());

create policy "org_scope_contacts" on contacts
  for all using (org_id = current_org_id()) with check (org_id = current_org_id());

create policy "org_scope_tags" on tags
  for all using (org_id = current_org_id()) with check (org_id = current_org_id());

create policy "org_scope_contact_tags" on contact_tags
  for all using (exists (select 1 from contacts c where c.id = contact_id and c.org_id = current_org_id()));

create policy "org_scope_pipelines" on pipelines
  for all using (org_id = current_org_id()) with check (org_id = current_org_id());

create policy "org_scope_stages" on stages
  for all using (exists (select 1 from pipelines p where p.id = pipeline_id and p.org_id = current_org_id()));

create policy "org_scope_deals" on deals
  for all using (org_id = current_org_id()) with check (org_id = current_org_id());

create policy "org_scope_activities" on activities
  for all using (org_id = current_org_id()) with check (org_id = current_org_id());

-- ============================================================
-- SEED: pipeline default al crear organización
-- ============================================================
create or replace function seed_default_pipeline(p_org_id uuid) returns uuid as $$
declare v_pipeline_id uuid;
begin
  insert into pipelines(org_id, name, is_default) values (p_org_id, 'Ventas', true) returning id into v_pipeline_id;
  insert into stages(pipeline_id, name, position, color, is_won, is_lost) values
    (v_pipeline_id, 'Prospecto',   1, '#94A3B8', false, false),
    (v_pipeline_id, 'Calificado',  2, '#4F46E5', false, false),
    (v_pipeline_id, 'Propuesta',   3, '#7C3AED', false, false),
    (v_pipeline_id, 'Negociación', 4, '#D97706', false, false),
    (v_pipeline_id, 'Ganado',      5, '#10B981', true,  false),
    (v_pipeline_id, 'Perdido',     6, '#DC2626', false, true);
  return v_pipeline_id;
end;
$$ language plpgsql security definer;
