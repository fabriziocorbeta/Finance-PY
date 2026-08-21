# CRM Social Hub

CRM + dashboard de redes sociales para negocios. Multi-tenant con WhatsApp Business + Meta (Instagram/Facebook).

## Estado actual: **Fase 1 — CRM Núcleo**

Roadmap completo: [`../docs/crm-roadmap-phases.md`](../docs/crm-roadmap-phases.md)

## Stack

- **Next.js 15** App Router + TypeScript + Tailwind
- **Supabase** Postgres + Auth + Realtime + RLS multi-tenant
- **Vercel** deploy (Fluid Compute)
- **dnd-kit** kanban drag-drop
- **Lucide** iconos SVG

## Setup local

```bash
# 1. Instalar deps
pnpm install   # o npm install

# 2. Crear proyecto Supabase en https://supabase.com/dashboard
#    Copiar URL + anon key + service role key

# 3. Variables de entorno
cp .env.example .env.local
# Llenar NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

# 4. Aplicar schema en Supabase SQL Editor (orden estricto)
#    a) Pegar y ejecutar: supabase/schema.sql
#    b) Pegar y ejecutar: supabase/seed-auth-trigger.sql  (auto-org en signup)

# 5. Dev server
pnpm dev

# 6. Primer signup
#    Ve a /login → "Magic link" o crea usuario desde Supabase Auth dashboard
#    Trigger auto-crea organización + profile + pipeline default
```

## Estructura

```
crm-app/
├── app/
│   ├── (auth)/login/        Login + magic link
│   ├── (app)/               Rutas autenticadas
│   │   ├── layout.tsx       Sidebar persistente
│   │   ├── dashboard/       KPIs + actividad
│   │   ├── contactos/       Lista + drawer detail
│   │   └── pipeline/        Kanban deals
│   └── api/                 Route handlers (Fase 2+: webhooks)
├── lib/supabase/            Clients SSR/CSR + middleware
├── supabase/schema.sql      Schema completo + RLS
├── types/database.ts        Tipos generados
└── middleware.ts            Auth gate global
```

## Comandos clave

```bash
pnpm dev                # dev server
pnpm build              # build producción
pnpm type-check         # validar TS
pnpm lint               # ESLint
```

## Próximos pasos Fase 1

- [ ] Crear proyecto Supabase
- [ ] Correr `supabase/schema.sql` + `supabase/seed-auth-trigger.sql`
- [ ] `pnpm install` + `.env.local` con keys
- [ ] Signup primer usuario → org + pipeline default auto-creados
- [ ] Probar: crear contacto, crear deal, drag-drop kanban, agregar actividades
- [ ] Deploy Vercel preview

## Lo que ya hace (F1)

- Login email+pass + magic link
- Auto-provisión org/profile/pipeline en signup (trigger)
- Lista de contactos + drawer "Nuevo contacto" con validación Zod
- Página detalle contacto + composer de actividades (note/call/email/meeting/task/message)
- Kanban deals con drag-drop (dnd-kit) + modal "Nuevo deal"
- Auto-marca deals como `won`/`lost` al mover a stages correspondientes
- Sign out
- Page integraciones (cards F2/F3 disabled placeholders)

## Fase 2 (próxima): WhatsApp

Pre-requisito externo crítico: **iniciar verificación Meta Business Manager YA** (tarda 3-5 días).
