---
type: source
title: "CD & Co ERP — IDOR crítico en RPC Supabase (resuelto)"
created: 2026-07-16
updated: 2026-07-16
status: resolved
tags:
  - cdco-erp
  - seguridad
  - supabase
  - idor
  - critico
related:
  - "[[CD & Co ERP]]"
  - "[[CD & Co ERP + FinancePY — Auditoría Supabase compartida (RLS crítico) + diagnóstico Vercel]]"
  - "[[Sesión 2026-07-16 FinancePY security fixes deploy]]"
---

# CD & Co ERP — IDOR crítico en 9 funciones RPC Supabase

**Severidad: crítica. Explotable sin autenticación, en producción, contra datos financieros reales.**

## Hallazgo

Auditoría de `pg_proc`/`get_advisors` sobre el proyecto Supabase "CD Finanzas" (`beumpltrjgnehqbhtrxo`) encontró 9 funciones `SECURITY DEFINER` en schema `public` que reciben `user_id`/`user_uuid` como **parámetro del llamador**, nunca lo verificaban contra `auth.uid()`, y eran ejecutables por el rol `anon` (no autenticado — la anon key es pública, va embebida en cualquier cliente Supabase).

Impacto real antes del fix: cualquiera con la anon key (trivialmente obtenible del bundle JS de la app) podía:
- Leer patrimonio neto, ingresos/gastos, deudas, tarjetas (incluyendo últimos 4 dígitos) de **cualquier usuario** vía `dashboard_stats`, `get_complete_dashboard_v2`, `get_user_debts_v1`, `get_user_cards_v1`.
- **Mutar** stock de productos y estado de conciliaciones bancarias de cualquier usuario vía `adjust_stock_atomic`, `deduct_stock_atomic`, `adjust_transit_atomic`, `marcar_conciliacion`.
- `recalculate_all_balances` (lectura, mutación actualmente no-op pero mismo patrón).

Las funciones `admin_list_profiles`/`admin_set_plan` (mismo archivo) SÍ tenían el chequeo correcto (`auth.uid()` contra email admin hardcodeado) — el patrón correcto ya existía, solo faltaba aplicarlo a estas 9.

## Fix aplicado (2026-07-16)

Migración `fix_idor_security_definer_functions` vía Supabase MCP `apply_migration`. Patrón: agregar al inicio de cada función:
```sql
IF p_user_id IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
END IF;
```
`IS DISTINCT FROM` maneja correctamente el caso `anon` (`auth.uid()` es `NULL`) — bloquea tanto cross-user como no-autenticado. Cero cambios a la lógica de negocio interna.

También se agregó `SET search_path TO 'public'` a las 8 que no lo tenían (hardening secundario contra search_path hijacking, separado del advisor `function_search_path_mutable`).

**Verificado en prod** (`set role anon`): `dashboard_stats` y `adjust_stock_atomic` ahora devuelven `42501: Acceso denegado` en vez de datos/mutación cuando se llaman con un `user_id` ajeno.

## Contexto: por qué apareció

Patrón típico cuando el frontend confía en pasar `auth.uid()` como parámetro explícito (`supabase.rpc('dashboard_stats', { p_user_id: session.user.id })`) asumiendo que el cliente "se porta bien" — sin enforcement server-side, cualquiera puede pasar OTRO uuid en la misma llamada RPC. El fix es el estándar: nunca confiar en un ID de usuario que venga como parámetro sin verificarlo contra la sesión autenticada real.

## Pendiente / recomendación

- ✅ **Verificado (2026-07-16):** schema `financespy` (Rails/FinancePY) tiene **cero funciones custom** — sin superficie IDOR ahí, es Rails-managed puro.
- Auditar si hay MÁS RPCs con el mismo patrón fuera de las 14 `SECURITY DEFINER` revisadas en `public` (esta auditoría cubrió el schema completo, pero vale una segunda pasada tras cualquier RPC nueva).
- El advisor de performance marcó 185 `unused_index` en `financespy` — no revisado en esta sesión, backlog.
- `auth_leaked_password_protection` (WARN) — activar protección contra passwords filtrados. **No hay tool MCP para esto** (vive en Supabase Dashboard → Authentication → Policies/Providers, o Management API fuera del alcance de las tools disponibles). Acción manual pendiente para Fabrizio.
