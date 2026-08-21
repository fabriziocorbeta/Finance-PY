---
type: emprendimiento
status: activo
created: 2026-07-07
updated: 2026-08-05
tags: [ia, whatsapp, agente, automatizacion, n8n, hermes]
---

# Agente IA CD & Co ("Alejandro")

Agente de WhatsApp para CD & Co: secretaria + asistente de negocio. **Activo
en producción real** (fix de seguridad crítico 2026-07-23: `/webhook` y
`/health/reconnect` sin autenticación, resuelto con HMAC-SHA256). Repo:
`fabriziocorbeta/AI-Agent1-Alejandro-CD-Co`.

## Rol
- Atención y triage de mensajes entrantes (WhatsApp, vía openwa-api/Chromium)
- Sistema de leads con scoring/funnel, integración Shopify, Instagram, GA4
- Subsistema **Hermes**: bot de Telegram del dueño (Fabrizio), memoria +
  tools propias, corre en paralelo al bot de clientes

## Infraestructura (decidida 2026-08-05)
Stack (n8n + alejandro-agent + openwa-api) migra de la VM GCP `alejandro-vm`
a una **PC de escritorio dedicada (Ryzen 3, 16GB RAM)**, con **Railway como
fallback** (no primario). Detalle completo, incluyendo la pregunta abierta
sobre si es la misma máquina que el HP EliteDesk ya documentado para
FinancePY, en [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]].

## Arquitectura n8n
Dos integraciones separadas y de estado muy distinto — bridge periférico
en producción real vs. router de tools de Hermes nunca mergeado a `main`.
Detalle completo en [[Agente IA CD & Co — arquitectura n8n (dos integraciones)]].

## Principios de diseño (ver [[Diseño de Subagentes]])
- Un agente = una responsabilidad
- Prompt autocontenido con formato de salida y criterio de éxito
- Comportamiento definido ante ambigüedad
- Logging de decisiones para auditoría
- Probar caso feliz + 2 casos hostiles antes de producción

## Relacionado
- [[CD & Co ERP]], [[fable-clon-skill]], [[financespy]]
