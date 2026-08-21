---
type: emprendimiento
title: "CRM Social Hub"
status: en-desarrollo
etapa: fase-1-operable
created: 2026-05-15
updated: 2026-05-15
tags: [crm, saas, whatsapp, instagram, facebook, nextjs, supabase]
---

# CRM Social Hub

CRM multi-tenant + dashboard de redes sociales con integraciones nativas WhatsApp Business, Instagram y Facebook. Construido para operar negocios desde un único panel: contactos, deals, conversaciones y métricas sociales.

## Objetivo

Operar el negocio sin saltar entre apps. Una sola bandeja de entrada que une WhatsApp, IG DM y FB Messenger, vinculada al contacto del CRM y al deal del pipeline.

## Stack

| Capa | Tecnología | Razón |
|------|------------|-------|
| Frontend | Next.js 15 App Router + TypeScript | SSR, server actions, deploy Vercel |
| Estilos | Tailwind 3.4 + design tokens Indigo/Violet | Velocidad, dark mode token-driven |
| DB + Auth | Supabase Postgres + RLS multi-tenant | Free tier 500MB, Realtime, auth incluido |
| Hosting | Vercel Fluid Compute | Node 24, timeout 300s, free tier |
| Drag-drop | @dnd-kit/core | Kanban pipeline |
| Icons | lucide-react | Vector, consistencia, tree-shake |
| WhatsApp (F2) | WhatsApp Business Cloud API | Free 1k conv service/mes |
| Meta IG+FB (F3) | Meta Graph API v21.0 | OAuth Business Login |

## Arquitectura

```
crm-app/
├── app/
│   ├── (auth)/login/        Login email/pass + magic link
│   ├── (app)/               Rutas autenticadas
│   │   ├── dashboard/       KPIs + actividad
│   │   ├── contactos/       Lista + drawer + server actions
│   │   ├── pipeline/        Kanban deals por stage
│   │   └── integraciones/   WA + Meta connect (F2/F3)
│   └── auth/callback/       OAuth + magic link callback
├── lib/supabase/            Clients SSR/CSR + middleware
├── supabase/schema.sql      Schema completo + RLS por org_id
├── types/database.ts        Tipos TS dominio
└── middleware.ts            Auth gate global
```

## Modelo de datos (Fase 1)

- **organizations** — tenant raíz (multi-org)
- **profiles** — vinculado a `auth.users` Supabase, FK `org_id`
- **contacts** — `full_name`, `phone`, `whatsapp`, `instagram`, `facebook_id`, `source`, `status`
- **tags** + **contact_tags** — etiquetado libre
- **pipelines** + **stages** — funnel configurable (default seeded: Prospecto → Calificado → Propuesta → Negociación → Ganado/Perdido)
- **deals** — `value_cents`, `currency`, `probability`, `stage_id`, `status`
- **activities** — timeline append-only: notas, llamadas, emails, mensajes, status_change, deal_moved

**RLS estratégico:** función `current_org_id()` filtra TODA tabla via `auth.uid()` → `profiles.org_id`. Imposible leer/escribir data de otra org desde cliente.

## Roadmap por fases

Ver: [[../../docs/crm-roadmap-phases]] (también: `docs/crm-roadmap-phases.md`)

| Fase | Semana | Estado | Entregable |
|------|--------|--------|------------|
| F1 — CRM Núcleo | 1-2 | ✅ código completo | Contactos + pipeline + actividades + drag-drop + auto-org. **OPERABLE** post-deploy DB. |
| F2 — WhatsApp | 3-5 | ⏳ pendiente | Inbox WA, webhooks, send/receive, templates |
| F3 — Instagram + Facebook | 6-7 | ⏳ pendiente | DMs IG, FB Messenger, OAuth Meta |
| F4 — Social tracking | 8-9 | ⏳ pendiente | Charts métricas, IG/FB Insights, cron diario |
| F5 — Automatización + IA | 10+ | ⏳ pendiente | Quick replies, auto-asignar, AI summary |

## Estado actual: Fase 1 código completo ✅

### Auto-provisión signup (crítico)
`supabase/seed-auth-trigger.sql` — trigger `on_auth_user_created` sobre `auth.users` insert:
1. Crea row en `organizations` (nombre desde `raw_user_meta_data.org_name` o email)
2. Crea row en `profiles` vinculado al user con rol `owner`
3. Llama `seed_default_pipeline(org_id)` → pipeline "Ventas" + 6 stages

Sin este trigger, el primer login termina con user sin `profiles` row → `current_org_id()` retorna `null` → RLS bloquea todo.

### Server actions implementadas
| Path | Acciones | Validación |
|------|----------|-----------|
| `contactos/actions.ts` | createContact, updateContact, deleteContact | Zod schema 11 campos |
| `contactos/[id]/actions.ts` | addActivity | kind enum, body required |
| `pipeline/actions.ts` | createDeal, moveDeal | UUID + auto won/lost por stage |
| `_actions/auth.ts` | signOut | — |

### Archivos creados
- `crm-app/package.json` — Next 15.1, React 19, Supabase SSR 0.5, dnd-kit, lucide, zod
- `crm-app/tsconfig.json`, `next.config.ts`, `tailwind.config.ts`, `postcss.config.mjs`
- `crm-app/.env.example` — slots Supabase + placeholders WA/Meta
- `crm-app/supabase/schema.sql` — 9 tablas + RLS + función `current_org_id()` + seed pipeline
- `crm-app/middleware.ts` + `lib/supabase/{client,server,middleware}.ts`
- `crm-app/app/layout.tsx` (DM Sans + Toaster)
- `crm-app/app/(auth)/login/page.tsx` — email+pass + magic link
- `crm-app/app/auth/callback/route.ts` — code exchange
- `crm-app/app/(app)/layout.tsx` — sidebar dark + topbar search
- `crm-app/app/(app)/dashboard/page.tsx` — KPIs server-side
- `crm-app/app/(app)/contactos/page.tsx` + `actions.ts` — lista + CRUD server actions
- `crm-app/app/(app)/pipeline/page.tsx` — kanban deals
- `crm-app/app/(app)/integraciones/page.tsx` — cards conexión (F2/F3 disabled)
- `crm-app/README.md`, `.gitignore`

### Pendiente para activar Fase 1
1. [ ] Crear proyecto Supabase
2. [ ] Correr `supabase/schema.sql` en SQL Editor
3. [ ] Correr `supabase/seed-auth-trigger.sql` (orden importa)
4. [ ] `pnpm install`
5. [ ] `.env.local` con NEXT_PUBLIC_SUPABASE_URL + NEXT_PUBLIC_SUPABASE_ANON_KEY
6. [ ] `pnpm dev`
7. [ ] Signup primer user (`/login` magic link o Supabase Auth dashboard)
8. [ ] Verificar: ir a `/pipeline` → pipeline default visible

### Lo que ya funciona
- Login email/pass + magic link
- Auto-org en signup vía trigger
- `/contactos`: lista, drawer "Nuevo contacto" con 9 campos, link a detalle
- `/contactos/[id]`: info + timeline actividades + composer inline (6 tipos)
- `/pipeline`: kanban dnd-kit, drag-drop con optimistic update, modal "Nuevo deal"
- Auto win/lost al mover deal a stage final
- Sign out
- `/integraciones`: cards placeholder F2/F3

## Decisiones técnicas clave

### Por qué Next.js + Supabase y no algo más simple
- Necesidad de **realtime inbox** (F2) — Supabase Realtime resuelve sin servidor
- **Webhooks WhatsApp/Meta** requieren endpoint público confiable — Vercel Route Handlers + Fluid Compute (Node 24, 300s timeout)
- **RLS multi-tenant** evita escribir auth manual
- Free tier de ambos cubre MVP holgadamente (Supabase 500MB, Vercel 100GB bandwidth)

### Por qué WhatsApp Cloud API directo (no Twilio/360dialog)
- Free tier 1000 conversaciones service/mes (Meta directo)
- Twilio cobra markup; no aporta valor para volumen MVP
- Migrar a proveedor más adelante si volumen lo justifica

### Por qué pipelines configurables (no hardcoded)
- Cada negocio tiene su funnel
- Schema soporta múltiples pipelines por org (ventas, soporte, onboarding)
- Default seed simplifica primer uso

## Bloqueador externo crítico

**Verificación Meta Business Manager** tarda 3-5 días hábiles. Iniciar YA en paralelo a desarrollo F1 — sin esto, F2 (WhatsApp) y F3 (IG/FB) no arrancan.

Pasos:
1. business.facebook.com → crear Business Manager
2. Verificar dominio (DNS TXT)
3. Crear WhatsApp Business Account
4. Solicitar número WA dedicado
5. Aprobar display name

## Costos esperados

| Etapa | Costo mensual |
|-------|---------------|
| F1 (núcleo) | $0 (Supabase + Vercel free tier) |
| F2 (1k WA conv/mes) | $0 (free tier Meta) |
| F2 (>1k WA service) | $0.005-0.08/conv según país |
| F3 (Meta IG/FB) | $0 (APIs gratis) |
| Escala: 10k conv/mes | ~$50-80 + posible upgrade Supabase Pro $25 |

## Hilos abiertos
- Decidir nombre comercial final (NexusCRM placeholder)
- Definir org inicial: ¿CD&Co? ¿negocio nuevo?
- Validar si conviene compartir Supabase con [[CD&Co ERP - Módulo de Exportación]] o instancia separada
- Verificación Meta Business iniciar esta semana

## Referencias
- [[../../docs/crm-roadmap-phases]] — roadmap detallado por fase
- [[../../docs/crm-dashboard-design]] — prototipo HTML diseño visual
- WhatsApp Cloud API docs: https://developers.facebook.com/docs/whatsapp/cloud-api
- Supabase SSR Next.js: https://supabase.com/docs/guides/auth/server-side/nextjs
