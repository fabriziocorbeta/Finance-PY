---
type: recurso
title: "WhatsApp AgentKit — Setup"
status: instalado
created: 2026-05-17
updated: 2026-05-17
tags: [whatsapp, agente-ia, python, agentkit, herramienta]
---

# WhatsApp AgentKit

Builder de agentes WhatsApp con IA guiado por Claude Code. Alternativa Python/FastAPI al stack Node.js/Express del [[Agente IA CD & Co.]].

## Repo

`https://github.com/Hainrixz/whatsapp-agentkit.git`

## Ubicación

```
/Google Drive/03 Emprendimientos/03 Agente WhatsApp/
```

## Stack generado

| Componente | Tech |
|------------|------|
| IA | Claude Sonnet 4.6 |
| Servidor | FastAPI + Uvicorn |
| WhatsApp | Meta Cloud API o Twilio |
| DB | SQLite (local) / PostgreSQL (prod) |
| Deploy | Docker + Railway |

## Requisitos

- Python 3.11+ (instalado 3.13.13 via `brew install python@3.13`)
- Claude Code instalado
- API Key de Anthropic
- Cuenta Meta Business o Twilio

## Uso

```bash
# Verificar entorno
cd "03 Agente WhatsApp"
PATH="/usr/local/opt/python@3.13/libexec/bin:$PATH" bash start.sh

# Construir agente (dentro de Claude Code)
/build-agent
```

Claude Code hace entrevista de 10 preguntas y genera todo el código automáticamente.

## Comandos post-setup

```bash
# Probar sin WhatsApp
python tests/test_local.py

# Servidor local
uvicorn agent.main:app --reload --port 8000

# Producción
docker compose up --build
```

## Nota importante

Python 3.10 es la versión por defecto del sistema. Para usar este proyecto siempre prefijar:
```bash
PATH="/usr/local/opt/python@3.13/libexec/bin:$PATH"
```

O agregar al `.zshrc`:
```bash
export PATH="/usr/local/opt/python@3.13/libexec/bin:$PATH"
```

## Relacionado

- [[Agente IA CD & Co.]] — implementación custom Node.js/Express para CD & Co.
- [[Agente IA - Costo Zero]] — estrategia de optimización de costos
