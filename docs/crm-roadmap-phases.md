# CRM + Social Dashboard — Roadmap por Fases

**Objetivo:** Operar en Fase 1 en ≤2 semanas. WhatsApp activo en Fase 2 (~3-4 semanas). Meta en Fase 3.

## Stack Base (decidido)

| Capa | Tecnología | Por qué |
|------|------------|---------|
| Frontend | Next.js 15 App Router | SSR, route handlers, deploy Vercel |
| Hosting | Vercel (Fluid Compute) | 300s timeout, Node 24, free tier suficiente MVP |
| DB + Auth | Supabase (Postgres + RLS) | Realtime, auth incluido, free tier 500MB |
| Realtime UI | Supabase Realtime | Inbox live sin polling |
| Estilos | Tailwind + design tokens (Indigo/Violet ya definidos) | Velocidad |
| Webhooks WA/Meta | Vercel Route Handlers `/api/webhooks/*` | Sin servidor dedicado |
| Cron | Vercel Cron (`vercel.ts`) | Sync metrics diario |

---

## Fase 1 — CRM Núcleo (Semana 1-2) 🎯 OPERABLE

**Meta:** Cargar contactos, mover deals, tomar notas. Sin integraciones.

### Tareas
- [ ] Schema Supabase: `contacts`, `deals`, `activities`, `tags`, `users`, `pipelines`, `stages`
- [ ] RLS policies por `org_id`
- [ ] Auth: Supabase email/password + magic link
- [ ] Páginas: `/contactos`, `/pipeline`, `/contactos/[id]`
- [ ] CRUD contactos (form drawer derecha)
- [ ] Kanban deals drag-drop (`@dnd-kit/core`)
- [ ] Timeline actividades por contacto (notas, llamadas, emails manuales)
- [ ] Import CSV contactos
- [ ] Búsqueda + filtros (estado, tag, fuente)

**Entregable:** App live en Vercel. Equipo cargando datos.

---

## Fase 2 — WhatsApp Business (Semana 3-5)

**Meta:** Recibir + responder WA desde inbox unificado.

### Pre-requisitos (externos, hacer YA)
- [ ] Meta Business Manager creado
- [ ] WhatsApp Business Account verificado
- [ ] Número telefónico dedicado (no usar personal)
- [ ] Display name aprobado por Meta

### Tareas técnicas
- [ ] Webhook endpoint: `/api/webhooks/whatsapp` (verify token + signature HMAC SHA256)
- [ ] Schema: `conversations`, `messages`, `channels`
- [ ] Receive: parse Cloud API payload → insert msg → realtime push
- [ ] Send: POST `graph.facebook.com/v21.0/{phone_id}/messages`
- [ ] UI Inbox: lista threads + chat view + composer
- [ ] Auto-crear contact si número no existe
- [ ] Templates WhatsApp (mensaje fuera ventana 24h)
- [ ] Estados: enviado/entregado/leído (webhook `statuses`)

**Costo:** Free 1000 conversaciones service/mes. Marketing $0.025-0.08 USD/conversación según país.

**Entregable:** Inbox WA funcional. Mensajes enlazan a contacto CRM.

---

## Fase 3 — Instagram + Facebook (Semana 6-7)

**Meta:** DMs IG + FB Messenger en mismo inbox.

### Tareas
- [ ] Meta App con productos: Instagram Graph API + Messenger Platform
- [ ] OAuth flow: `/api/auth/meta` → permisos `instagram_basic`, `instagram_manage_messages`, `pages_messaging`, `pages_read_engagement`
- [ ] Guardar `page_access_token` + `ig_business_account_id` cifrado
- [ ] Webhook unificado `/api/webhooks/meta` (objetos `instagram`, `page`)
- [ ] Send IG DM: `POST /{ig_id}/messages`
- [ ] Send FB msg: `POST /{page_id}/messages`
- [ ] Etiquetas plataforma en threads (WA/IG/FB)
- [ ] Ventana 24h messaging compliance

**Entregable:** Inbox tri-canal. Una conversación por contacto multi-plataforma.

---

## Fase 4 — Social Tracking (Semana 8-9)

**Meta:** Métricas seguidores, engagement, posts en dashboard.

### Tareas
- [ ] Cron diario `/api/cron/sync-metrics` (Vercel Cron 0 6 * * *)
- [ ] Pull IG Insights: `followers_count`, `impressions`, `reach`, `engagement`
- [ ] Pull FB Page Insights
- [ ] Schema: `social_metrics` (snapshot diario)
- [ ] Charts dashboard: line chart trend, donut audiencia, heatmap horas pico
- [ ] Top posts ranking

---

## Fase 5 — Automatización + IA (Semana 10+)

- [ ] Quick replies / templates
- [ ] Auto-asignar conversación por keyword
- [ ] Auto-avanzar deal stage al recibir mensaje
- [ ] AI summary conversación (Vercel AI Gateway + Claude Haiku)
- [ ] AI sugerir respuesta
- [ ] Reportes semanales por email

---

## Próximo Paso Inmediato

1. **Crear proyecto Supabase** (free tier)
2. **Crear app Next.js**: `pnpm create next-app crm-app --ts --app --tailwind`
3. **Iniciar Fase 1 schema** (script SQL listo en próximo doc)
4. **Paralelo:** abrir Meta Business Manager + verificación WA (3-5 días burocráticos)

¿Empezar con scaffold Next.js + schema SQL Fase 1?
