---
type: meta
title: "Índice Principal"
created: 2026-05-05
updated: 2026-08-20
tags: [meta, index]
---

# Sistema — Índice Principal

Catálogo maestro de todo el vault. Actualizar en cada ingest.

## Emprendimientos
| Página | Estado | Última actualización |
|--------|--------|----------------------|
| [[Tienda Online CD & Co]] | activo | 2026-07-07 |
| [[WhatsApp AgentKit — Setup]] | instalado | 2026-05-17 |
| [[Agente IA CD & Co]] | **activo en producción real**, hosting decidido (PC Ryzen3/16GB + Railway fallback) | 2026-08-05 |
| [[Agente IA CD & Co — arquitectura n8n (dos integraciones)]] | investigación completa | 2026-08-05 |
| [[Agente IA - Costo Zero]] | implementado | 2026-05-17 |
| [[CRM Social Hub]] | en-desarrollo (F1 production-correct) | 2026-05-17 |
| [[CD&Co ERP - Módulo de Exportación]] | implementado | 2026-05-06 |
| [[FinancePY - Módulos Premium ERP]] | en-desarrollo (toggle shipped) | 2026-07-03 |
| [[financespy]] | activo (resumen) | 2026-07-07 |
| [[CD & Co ERP]] | activo (resumen) | 2026-07-07 |
| [[FinancePY — Auditoría de seguridad y code smells (75 hallazgos)]] | resolved (13 PRs, CI verde, prod verificado) | 2026-07-18 |
| [[Sesión 2026-07-16 FinancePY security fixes deploy]] | sesión (cerrada) | 2026-07-18 |
| [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]] | **ejecutado y en producción real** (notebook sirviendo finance.cd-co.com.py, VM GCP apagada) | 2026-08-08 |
| [[FinancePY — APK Android (TWA) con Bubblewrap]] | APK generado (sideload, sin Play Console) — ⚠️ 1 de 3 iniciativas móviles sin decisión tomada (ver sesión 11-12/08) | 2026-08-07 |
| [[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]] | endpoints+cliente offline shippeados y verificados; rama sin mergear, recién pusheada a GitHub | 2026-08-08 |
| [[Sesión 2026-08-11-12 FinancePY RN app login OAuth resuelto]] | **login resuelto** — causa real: `--build` faltante en deploy, no bugs de código; expuso 3ra iniciativa móvil (RN app captura Wallet) sin decisión vs. TWA/Capacitor | 2026-08-12 |
| [[Sesión 2026-08-13 FinancePY unificación móvil + puente SSH Tailscale + QA wallet capture]] | **código Kotlin recuperado y versionado** (nunca estuvo en git), fixes movidos de rama equivocada a main, dedup + auto-categorización de wallet capture agregados — pendiente confirmación del usuario | 2026-08-14 |
| [[Sesión 2026-08-20 FinancePY wave 1b cierre + PR 74 + diseño bloquea 1c-1d]] | **wave 1b cerrada** (Reglas CRUD nativo verificado en prod), PR #74 mergeado+deployado, **diseño real (Sure design system) pasa a bloquear wave 1c/1d** — 3 prompts CRUD delegados a Jules en paralelo | 2026-08-20 |
| [[FinancePY — Arranque automatico y fallback (notebook WSL2)]] | guía lista, no aplicada | 2026-08-06 |
| [[CD & Co ERP — IDOR crítico en RPC Supabase (resuelto)]] | resuelto (crítico) | 2026-07-16 |
| [[Sesión 2026-07-22-23 FinancePY ventas + seguridad + migración]] | sesión (cerrada) | 2026-07-23 |
| [[Reporte de modificaciones — FinancePY 2026-07-23]] | reporte (referencia) | 2026-07-23 |
| [[FinancePY — Guía paso a paso migración VM a notebook Windows]] | lista para ejecutar | 2026-08-04 |
| [[FinancePY — entorno dev local bloqueado en Mac]] | bloqueado (ruby/postgres/docker faltan) | 2026-08-05 |
| [[FinancePY - Spec Módulos Neto (recurrentes, notificaciones, inversiones)]] | **diagnóstico**: notificaciones ya construidas y rotas (sospecha: separador de miles PYG); resto del reporte mayormente redundante | 2026-08-08 |

## Decisiones
| Página | Fecha | Estado |
|--------|-------|--------|
| [[Decisión Agente IA Modelo]] | 2026-05-17 | implementado |
| [[FinancePY - Hosting fase prueba (PC local)]] | 2026-07-18 | **ejecutado y en producción (2026-08-08)** — retomado sin Tailscale, con Cloudflare Tunnel como estaba planeado |

## Stakeholders
| Persona/Empresa | Rol | Relación |
|-----------------|-----|----------|
| —               | —   | —        |

## Intel / Mercado
| Página | Tema | Fecha |
|--------|------|-------|
| [[Fable 5 pago por uso]] | pricing IA / Anthropic | 2026-07-07 |
| [[Pasarelas de Pago Paraguay - Comparativa 2025]] | Comparativa UPay / Dinelco / PagoPar | 2026-05-05 |

## Metas
| Meta | Área | Progreso | Fecha límite |
|------|------|----------|--------------|
| —    | —    | —        | —            |

## Áreas de Vida
| Área | Estado | Notas |
|------|--------|-------|
| Salud | activa | — |
| Finanzas | activa | — |
| Carrera | activa | — |
| Creativo | activa | — |

## Aprendizaje
| Concepto/Skill | Estado | Fuente |
|----------------|--------|--------|
| [[Dirección de Modelos IA]] | en-desarrollo | clon.pdf + práctica |
| [[Diseño de Subagentes]] | en-desarrollo | práctica + fable-clon-skill |
| [[Contenido para Redes]] | en-desarrollo | fable-clon-skill §3.4 |
| [[Ecommerce de Relojes]] | en-desarrollo | destilado Fable 5 |
| [[Ecommerce de Perfumes]] | en-desarrollo | destilado Fable 5 |
| [[Agencias de IA]] | en-desarrollo | destilado Fable 5 |
| [[Agente IA - AB Testing]] | pendiente ejecución | cdco-agent sessions |

## Recursos
| Recurso | Tipo | Rating |
|---------|------|--------|
| [[fable-clon-skill]] | skill/playbook IA | — |
| [[Gems de Gemini]] | prompts/workflow IA | — |
| [[Proyectos de Claude Chat]] | prompts/workflow IA | — |
