---
type: emprendimiento
status: activo
created: 2026-07-07
updated: 2026-07-07
tags: [erp, supabase, vercel, javascript]
---

# CD & Co ERP

ERP en JavaScript + Supabase, desplegado en Vercel.

## Stack
- Frontend JS en Vercel
- Backend Supabase (Postgres + RLS + Edge Functions)
- Comparte repo con [[financespy]] vía branch `version-1.1.0`

## Estado
- En hardening: RLS (row level security en todas las tablas) + PWA

## Riesgos técnicos
- RLS incompleto = fuga de datos entre tenants — prioridad #1 del hardening
- Compartir repo entre dos productos: cuidar merges cruzados entre branches

## Relacionado
- [[financespy]], [[Agente IA CD & Co]], [[fable-clon-skill]]
