---
type: proyecto
title: "Agente IA CD & Co."
status: en-producción
created: 2026-05-17
updated: 2026-05-19
tags: [cdco, agente-ia, whatsapp, claude, openwa, ventas]
---

# Agente IA CD & Co.

Agente WhatsApp dual-mode para CD & Co. (relojes en Paraguay). Funciona como **Alejandro** (vendedor humano) para clientes y como **asistente de negocio** para Fabri.

## Estado Actual (2026-05-19)

- **Corriendo localmente** en Mac con Docker
- **OpenWA** como gateway WhatsApp (no Meta Cloud API)
- **OWNER_ONLY_MODE=true** — solo responde a Fabri mientras se entrena
- Delay humano implementado (1.5s–8s según largo de respuesta)

## Stack Real

| Componente | Elección | Razón |
|------------|----------|-------|
| LLM | Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) | 15x más barato que Sonnet |
| Prompt caching | `cache_control: { type: 'ephemeral' }` | -80% tokens por llamada |
| WhatsApp Gateway | OpenWA (Docker, puerto 2785) | Local, sin aprobación Meta |
| Dashboard | OpenWA Dashboard (puerto 2886) | UI para gestionar sesiones |
| Framework | Express.js + TypeScript | Simple, tsx watch en dev |
| Hosting | Mac local (por ahora) | Pendiente migrar a Railway |

## Arquitectura

```
WhatsApp ←→ OpenWA :2785 ←→ Agente Express :3000 ←→ Claude API
                    ↑
              Dashboard :2886
```

## Estructura de Archivos

```
OpenWA/
├── docker-compose.dev.yml    ← containers OpenWA (API + Dashboard)
├── data/.api-key             ← key del dashboard: dev-admin-key
└── agent/
    ├── .env                  ← vars de entorno
    ├── src/
    │   ├── index.ts          ← servidor Express + webhook handler
    │   ├── claude.ts         ← cliente Claude con prompt caching
    │   └── prompts.ts        ← SECRETARY_PROMPT + ASSISTANT_PROMPT
    └── package.json
```

## Variables de Entorno (agent/.env)

```env
ANTHROPIC_API_KEY=sk-ant-...
OPENWA_API_URL=http://localhost:2785
OPENWA_SESSION_ID=275d5c08-b6f3-4f4d-91f4-9b2d48adee72
OPENWA_API_KEY=dev-admin-key
OWNER_PHONE=92672643596391        # ID interno WhatsApp de Fabri (@lid format)
OWNER_ONLY_MODE=true              # false = activo para clientes
PORT=3000
```

## Comportamiento

### Modo Cliente (SECRETARY_PROMPT)
- Nombre: **Alejandro**, del equipo de CD & Co.
- Nunca menciona ser bot/IA
- Responde en ≤3 oraciones, máximo 1 emoji
- Deriva reclamos complejos a Fabrizio

### Modo Dueño (ASSISTANT_PROMPT)
- Activado cuando `from` === `OWNER_PHONE`
- Asistente personal de Fabrizio
- Acceso a consultas del negocio

### Anti-ban
- Delay humano: `1500ms + (50ms × chars_respuesta) + jitter(0-1000ms)`
- Cap: 8 segundos máximo

## Contexto del Negocio (en el prompt)

- **Marcas:** Casio, Seiko, Citizen, Invicta, Casio Edifice, G-Shock
- **Precios desde:** Gs. 350.000
- **Envíos:** gratis, 3-7 días hábiles, todo el país
- **Garantía:** 3 meses maquinaria, no incluye daños por agua
- **Web:** https://www.cd-co.com.py
- Sin local físico — venta 100% online

## Cómo Levantar

```bash
# 1. Iniciar OpenWA
cd OpenWA && docker compose -f docker-compose.dev.yml up -d

# 2. Conectar WhatsApp
# → localhost:2886 → Sessions → New Session → escanear QR

# 3. Registrar webhook (reemplazar SESSION_ID)
curl -X POST http://localhost:2785/api/sessions/{SESSION_ID}/webhooks \
  -H "X-API-Key: dev-admin-key" \
  -H "Content-Type: application/json" \
  -d '{"url":"http://host.docker.internal:3000/webhook","events":["message.received"]}'

# 4. Levantar agente
cd OpenWA/agent && npm run dev
```

## Problema Conocido: Sesión se cae al reiniciar Docker

Al reiniciar Docker Desktop, la sesión WhatsApp queda en `failed`. Hay que:
1. Ir a localhost:2886 → Sessions → Delete
2. Crear nueva sesión y escanear QR
3. Registrar webhook nuevamente con el nuevo SESSION_ID
4. Actualizar `OPENWA_SESSION_ID` en agent/.env

## Roadmap

### Fase 1 — Entrenamiento (actual)
- [x] OpenWA corriendo local
- [x] Agente responde con contexto CD & Co.
- [x] OWNER_ONLY_MODE para entrenamiento seguro
- [x] Anti-ban delay humano
- [ ] Agregar precios reales de productos
- [ ] Definir y documentar medios de pago reales
- [ ] Probar y ajustar respuestas con casos reales

### Fase 2 — Activar para clientes
- [ ] `OWNER_ONLY_MODE=false`
- [ ] Monitorear conversaciones reales
- [ ] Ajustar prompt según feedback

### Fase 3 — Estabilidad
- [ ] Auto-reconexión cuando sesión falla
- [ ] Persistencia historial en Supabase
- [ ] Alertas si el agente cae

### Fase 4 — Asistente Personal Fabri
- [ ] Expandir ASSISTANT_PROMPT con contexto personal
- [ ] Herramientas: ventas del día, leads pendientes, etc.

### Fase 5 — Migración a Producción
- [ ] Evaluar: seguir con OpenWA local vs migrar a Meta Cloud API
- [ ] Si Meta: configurar webhook + verificación
- [ ] Deploy Railway o equivalente

## Relacionado

- [[Agente IA - Costo Zero]] — estrategia de optimización de costos
- [[Decisión Agente IA Modelo]] — por qué Haiku 4.5 + caching
- [[CD&Co ERP]] — sistema de gestión relacionado
