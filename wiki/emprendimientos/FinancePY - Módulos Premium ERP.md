---
type: emprendimiento
title: "FinancePY - Módulos Premium ERP"
status: en-desarrollo (fundación shipped)
created: 2026-07-03
updated: 2026-07-03
tags: [emprendimiento, financepy, erp, premium]
---

# FinancePY — Módulos Premium ERP

Iniciativa para portar los 4 módulos de negocio del [[Agente IA CD & Co.|CD & Co ERP]] (Inventario y productos, Ventas y facturación, Pedidos a proveedores, Flota/vehículos) a FinancePY como features premium, manteniendo siempre el formato/estilo del front de FinancePY. Gate: un solo toggle admin (sin billing).

## Estado

- **Sub-proyecto 1 — Business Mode Toggle: SHIPPED** (commit `a80f2f6`, deployado a producción 2026-07-03)
  - `families.business_mode_enabled` (boolean, default false)
  - `RequireBusinessMode` concern — bloquea acceso si la family no tiene el flag
  - `Admin::FamiliesController` — panel en Settings → "Business Mode", solo super_admin
  - Verificado en VM: migración aplicada, container levantado, sitio responde
- **Sub-proyectos 2-5 (Inventario, Ventas/Facturación, Pedidos a proveedores, Flota): PENDIENTES** — cada uno necesita su propio spec → plan → implementación, arrancando una vez confirmado el toggle en uso real.

## Decisiones clave

- Alcance del toggle: un solo interruptor admin por familia, no un sistema de planes/billing
- Scope de acceso: solo `super_admin` puede togglear
- Multi-tenancy: por familia (`Current.family.business_mode_enabled?`)
- Estilo: siempre el formato visual nativo de FinancePY, nunca reusar componentes del ERP JS

## Deferida

Soporte para crear/cambiar a una segunda familia con la cuenta ya logueada (multi-familia por usuario) — explícitamente pospuesta hasta terminar esta iniciativa.

## Referencias

- Spec: `docs/superpowers/specs/2026-07-03-business-mode-toggle-design.md`
- Plan: `docs/superpowers/plans/2026-07-03-business-mode-toggle.md`
- Ver también: [[FinancePY]] (si existe), [[CD&Co ERP - Módulo de Exportación]]
