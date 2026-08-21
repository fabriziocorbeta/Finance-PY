---
type: decision
title: "Decisión: Modelo Agente IA CD&Co"
status: implementado
created: 2026-05-17
updated: 2026-05-17
tags: [cdco, agente-ia, decision, haiku, claude, modelo]
decider: Fabrizio
---

# Decisión: Modelo del Agente IA

**Decisión:** Claude Haiku 4.5 + Prompt Caching + Meta Cloud API (no Twilio)

## Contexto

Necesitamos un agente WhatsApp para CD & Co. que sea económicamente viable para un negocio pequeño. El agente debe manejar ventas conversacionales, coordinar pagos y entregas, y capturar leads.

## Opciones Evaluadas

### Opción A: GPT-4o + Twilio

- Costo: $52-75/mes
- Calidad de respuesta: alta
- Velocidad: 2-5s
- **Descartado:** costo inaceptable para escala pequeña

### Opción B: Claude Sonnet + Twilio

- Costo: $45-60/mes
- Calidad: muy alta
- Velocidad: 2-5s
- **Descartado:** mismo problema de costo

### Opción C: Claude Haiku 4.5 + Meta API ✅

- Costo: $0.07-0.75/mes
- Calidad: suficiente para ventas conversacionales
- Velocidad: ~500ms (mejor experiencia de usuario)
- Caching: -80% en tokens de sistema
- **Elegido**

## Rationale

1. **Haiku 4.5 es suficiente.** Las ventas conversacionales no requieren razonamiento complejo. El sistema prompt define el framework — el modelo solo ejecuta.

2. **Prompt caching cambia la ecuación.** El system prompt de ~2000 tokens se cachea por 5 min. Con cache hit, el costo por conversación baja 80%.

3. **Meta Cloud API es gratuita hasta 1000 conv/mes.** CD & Co. no llega a ese volumen en el arranque.

4. **Supabase free tier.** 500MB es amplio para el volumen inicial.

5. **Velocidad importa en WhatsApp.** 500ms vs 3s hace que el agente se sienta más natural en chat.

## Consecuencias

- Si el volumen crece a >1000 conv/mes, Meta API cobra $0.0088/conv adicional (aún barato)
- Si necesitamos razonamiento más complejo en futuro (multi-step quotes, análisis de mercado), podemos escalar a Sonnet solo para esos flows
- El modelo se configura via env var `AGENT_MODEL` — fácil de cambiar sin código

## Revisión

Revisar si:
- Cache hit ratio < 50% (significa que el prompt caching no está funcionando)
- Error rate > 5% (Haiku no está entendiendo bien las instrucciones)
- Conversión < 15% (el modelo puede necesitar más capacidad de razonamiento)

## Relacionado

- [[Agente IA CD & Co.]] — implementación completa
- [[Agente IA - Costo Zero]] — análisis de costos detallado
