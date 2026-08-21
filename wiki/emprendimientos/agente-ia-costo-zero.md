---
type: estrategia
title: "Agente IA - Costo Zero"
status: implementado
created: 2026-05-17
updated: 2026-05-17
tags: [cdco, agente-ia, costos, optimizacion, haiku, caching]
---

# Agente IA — Estrategia Costo Zero

Cómo llevamos el costo de un agente WhatsApp de **$47-62/mes** a **$0.07-0.75/mes**.

## Problema Original

Un agente WhatsApp típico con GPT-4o o Claude Sonnet costaba:
- 100 conversaciones/día × 30 días × $0.015/conv = **$45-60/mes**
- Más Twilio WhatsApp: $7-15/mes adicional
- **Total: $52-75/mes** inaceptable para negocio pequeño

## Solución: 5 capas de optimización

### Capa 1: Modelo correcto (10x ahorro)

| Modelo | Input $/1M | Output $/1M | Velocidad |
|--------|-----------|------------|-----------|
| Claude Sonnet | $3.00 | $15.00 | 2-5s |
| **Claude Haiku 4.5** | **$0.80** | **$4.00** | **~500ms** |

Haiku es suficiente para ventas conversacionales. No necesitamos razonamiento complejo.

### Capa 2: Prompt Caching (80% ahorro en tokens sistema)

```javascript
// claude.js — system block con cache_control
{
  type: 'text',
  text: systemPrompt,       // ~2000 tokens
  cache_control: { type: 'ephemeral' }  // cached por 5 min
}
```

Sin caching: 2000 tokens × cada llamada = $0.0016/conv
Con caching: 2000 tokens solo en 1ra llamada → $0.0003/conv promedio

### Capa 3: FAQ Router (eliminación de llamadas LLM)

```javascript
// faq.js — respuestas fijas sin LLM
const FAQ = [
  { pattern: /horario|atención|abr[ií]s/, response: 'Atendemos L-V 9-18h...' },
  { pattern: /garant[íi]a/, response: 'Todos los relojes tienen garantía...' },
  // ...6 patrones
]
```

Estimado: 20-30% de mensajes son FAQ → **0 costo LLM** para esos.

### Capa 4: Meta Cloud API vs Twilio

| Opción | Costo base | Mensajes |
|--------|-----------|---------|
| Twilio WhatsApp | $7-15/mes | Por mensaje |
| **Meta Cloud API** | **$0** | **Gratis ≤1000 conv/mes** |

### Capa 5: Supabase Free Tier

- 500MB DB, 2GB storage, 50K auth users — suficiente para arrancar
- Sin costo hasta escala real

## Resultado

```
Sin optimización: $52-75/mes
Con optimización:  $0.07-0.75/mes
Ahorro:            ~98%
```

## Monitoreo

Cada conversación guarda en `conversations`:
```sql
tokens_input  INT    -- para calcular costo real
tokens_output INT
cache_hit     BOOL   -- true = se usó cache de prompt
variant       TEXT   -- A (sin FAQ) / B (con FAQ)
```

Query de costo real:
```sql
SELECT 
  SUM(tokens_input * 0.0000008 + tokens_output * 0.000004) AS costo_usd,
  AVG(cache_hit::int) * 100 AS cache_hit_pct
FROM conversations
WHERE timestamp > NOW() - INTERVAL '30 days';
```

## Límites del free tier

| Servicio | Límite free | Cuándo pagar |
|----------|-------------|--------------|
| Meta API | 1000 conv/mes | +1000 conv/mes → $0.0088/conv adicional |
| Supabase | 500MB DB | Cuando supere volumen |
| Railway | $5 crédito/mes | Después del crédito |

## Relacionado

- [[Agente IA CD & Co.]] — arquitectura completa
- [[Decisión Agente IA Modelo]] — por qué Haiku 4.5
