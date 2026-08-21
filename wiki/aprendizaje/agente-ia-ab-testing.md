---
type: aprendizaje
title: "Agente IA - Plan A/B Testing"
status: pendiente
created: 2026-05-17
updated: 2026-05-17
tags: [cdco, agente-ia, ab-testing, experimentos, conversion]
---

# Agente IA — Plan A/B Testing

Experimentos para optimizar tasa de conversión y reducción de costo del agente WhatsApp CD & Co.

## Variantes Activas

La columna `variant` en tabla `conversations` trackea la variante.

### Variante B (actual — baseline)

- FAQ router activo
- SECRETARY_PROMPT con framework 6 fases
- Haiku 4.5 + prompt caching
- Captura de leads automática

### Variante A (control)

- Sin FAQ router (todo pasa por Claude)
- Mismo prompt
- Mide cuánto ahorra el FAQ router en tokens reales

## Experimentos Planeados

### Exp 1: Impacto FAQ Router

**Hipótesis:** El FAQ router reduce 20-30% de llamadas LLM sin afectar satisfacción.

**Métricas:**
- `cache_hit` ratio
- `tokens_input` promedio
- Tiempo de respuesta

**Cómo medir:**
```sql
SELECT 
  variant,
  COUNT(*) as total_conv,
  AVG(tokens_input) as avg_tokens,
  SUM(tokens_input = 0)::float / COUNT(*) * 100 as faq_hit_pct
FROM conversations
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY variant;
```

### Exp 2: Efectividad de Cierres

**Hipótesis:** Las técnicas de cierre asuntivo ("¿Asunción o Luque?") convierten más que esperar que el cliente diga "lo quiero".

**Métricas:**
- Ratio conversaciones → quote creada
- Tiempo hasta primer quote
- Objección más común (tabla leads)

**Cómo medir:**
```sql
-- Conversión por objeción
SELECT objection, COUNT(*), 
       SUM(CASE WHEN status='converted' THEN 1 ELSE 0 END) as converted
FROM leads
GROUP BY objection
ORDER BY converted DESC;
```

### Exp 3: Lead Recovery

**Hipótesis:** Los leads con objeción "lo_piensa" se convierten >40% si se contactan dentro de 24h.

**Métricas:**
- Tiempo entre capture_lead y mark_lead_contacted
- Tasa de conversión por tiempo de follow-up
- Objeciones con mayor conversion rate

## Dashboard de Seguimiento

```sql
-- Resumen semanal
SELECT 
  DATE_TRUNC('week', timestamp) as semana,
  COUNT(*) as conversaciones,
  COUNT(DISTINCT phone) as clientes_unicos,
  SUM(CASE WHEN tokens_input = 0 THEN 1 ELSE 0 END) as faq_interceptados,
  AVG(tokens_input) as avg_tokens_in,
  AVG(tokens_output) as avg_tokens_out,
  SUM(cache_hit::int)::float / COUNT(*) * 100 as cache_pct
FROM conversations
GROUP BY 1
ORDER BY 1 DESC;
```

## Resultados (pendiente)

| Experimento | Fecha inicio | Resultado | Acción |
|-------------|-------------|-----------|--------|
| Exp 1: FAQ Impact | pendiente | — | — |
| Exp 2: Cierre Asuntivo | pendiente | — | — |
| Exp 3: Lead Recovery | pendiente | — | — |

## Relacionado

- [[Agente IA CD & Co.]] — arquitectura completa
- [[Agente IA - Costo Zero]] — optimización de costos
