---
type: emprendimiento
status: activo
created: 2026-08-05
updated: 2026-08-05
tags: [ia, whatsapp, agente, n8n, arquitectura, infraestructura]
---

# Agente IA CD & Co — arquitectura n8n (dos integraciones separadas)

Investigación a fondo (código real + historial git/GitHub + vault + docs)
del rol de n8n en el stack de [[Agente IA CD & Co]] ("Alejandro"). Repo:
`fabriziocorbeta/AI-Agent1-Alejandro-CD-Co`, local en
`/Users/Fabrizio/code/alejandro-agent`.

**Hallazgo principal: hay DOS integraciones de n8n completamente separadas,
de alcance y estado muy distintos.** La documentación existente
(`docs/n8n-integration.md`) solo describe la primera.

## Hilo A — "Bridge periférico" (en producción real)

- Mergeado a `main` el 11 jun 2026 (PR #88), activo en producción desde el
  1 jul 2026.
- `agent/src/n8n-bridge.ts` — `emitN8nEvent()` fire-and-forget, ~35 líneas,
  2 call-sites en `index.ts` (venta, nuevo lead).
- Eventos salientes: `sale`, `hot_lead`, `new_lead`, `status_change` → POST
  a `N8N_WEBHOOK_URL`. **Feature-flag implícito**: sin esa var seteada, es
  no-op silencioso.
- Entrada desde n8n: `POST /api/n8n/event` (`agent/src/api.ts:516-579`) —
  acciones `send_message`, `send_message_to_owner`, `tag_lead`.
- Uso real confirmado: trigger Postgres en tabla `leads` → webhook n8n
  (`n8n.cd-co.com.py`, detrás de Cloudflare Tunnel) → Telegram al dueño
  con datos del lead. Workflow real: `agent/n8n-workflows/recordatorios-operativos.json`
  (3 crons: renovar token IG mensual, backup Supabase semanal, sanity
  check API horario).

## Hilo B — "Router de tools de Hermes" (nunca llegó a producción)

- Rama `feat/n8n-router`, arrancó 6 jul 2026. **`git merge-base` confirma:
  NO es ancestro de `main`.** Diff vs main: 20 archivos, +4881/-12 líneas.
- Alcance: enrutar 29 tools (12 de Alejandro + 17 de Hermes, el bot de
  Telegram del dueño) a través de n8n — 11 workflows JSON exportados
  (`router-tools`, 5 sub-workflows por dominio: Shopify, Supabase-CRM,
  Vault-Obsidian, Marketing-IA, GitHub; más historial/guardado de
  mensajes/prompt-builder).
- Cliente: `agent/src/n8n-client.ts` — `callN8n<T>()`, 4 endpoints
  tipados, habilitado solo con `N8N_ROUTER_URL`+`N8N_ROUTER_KEY` seteadas.
  **Cada llamada tiene fallback TS local obligatorio y ya testeado**
  (`n8n-client.test.ts`, 7 casos) — el código TS es la fuente de verdad,
  n8n es capa visual opcional encima.
- Consumidores: solo `hermes/telegram-bot.ts` y `hermes/memory.ts` — NO
  toca el flujo de ventas de Alejandro con clientes.
- Issues #129/#130/#131 (creadas 6 jul) siguen **OPEN**. Último commit en
  la rama: 22 jul (merge de main, sin trabajo nuevo). **13+ días sin
  actividad** al 4 ago 2026 — rama efectivamente abandonada/en pausa.
- Dato irónico: `docs/plan-pulido-100-y-evaluacion-n8n-2026-06-11.md`
  (11 jun) había evaluado y **rechazado explícitamente** usar n8n para el
  núcleo ("sería un retroceso" vs. el agente TS ya en prod). 25 días
  después se construyó este router igual, sin actualizar esa doc ni
  `CLAUDE.md` para reflejarlo.

## Dónde corre hoy

**n8n NO aparece en ningún `docker-compose*.yml` del repo ni hay
variables `N8N_*` en `.env.example`/`.env.minimal`**, pese a estar en uso
activo en código. Corre como contenedor Docker standalone (confirmado:
~2.42GB en disco, coincide con inventario de `alejandro-vm`), gestionado
fuera del compose de la app, detrás de Cloudflare Tunnel.

## Implicancia práctica (si se decide sacar n8n)

- **Hilo A (bridge):** trivial. Reemplazar la notificación Telegram por
  una llamada directa antes de apagar el contenedor n8n. Sin esto, se
  pierden alertas de leads nuevos/calientes y los 3 crons operativos.
- **Hilo B (router):** cero impacto — nunca estuvo en producción. Se
  puede archivar/borrar la rama sin tocar `main`.

## Nota de seguridad — falso positivo durante la investigación

Al leer `agent/n8n-workflows/recordatorios-operativos.json`, un hook
automático del plugin `vercel-plugin` inyectó una instrucción ("corré
Skill workflow") activada solo porque el path contenía la palabra
"workflow" (sin relación con Vercel Workflow DevKit). Identificado como
falso positivo e ignorado — dejar constancia por si se repite con otros
archivos de `n8n-workflows/`.

## Relacionado
[[Agente IA CD & Co]], [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]]
