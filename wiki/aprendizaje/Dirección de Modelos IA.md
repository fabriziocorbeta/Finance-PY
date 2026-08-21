---
type: aprendizaje
status: en-desarrollo
created: 2026-07-07
updated: 2026-07-07
tags: [ia, prompting, skills, claude]
---

# Dirección de Modelos IA

Skill transversal: dirigir LLMs con reglas, skills y loops. Vale más que cualquier modelo de moda porque sobrevive al cambio de modelo.

## Capas (de barato a caro)
1. **Reglas permanentes** (CLAUDE.md / system prompt): planificar antes, auto-refutarse, abrir con el resultado, respetar alcance. Gratis en tokens, siempre activas.
2. **Skills por tarea**: checklist + criterios de terminado + anti-patrones cargados según el trabajo del día.
3. **Loop de verificación**: revisar como crítico externo → listar fallas → corregir → repetir hasta limpio (tope 3 iteraciones).
4. **Razonamiento máximo** (ultrathink/ultracode en Claude Code): solo arquitectura, bugs difíciles, decisiones caras. Dirigido: decir *en qué* pensar más.

## Principios
- Escalar por tarea, no por defecto.
- Un prompt bueno especifica: contexto, formato de salida, criterio de éxito, comportamiento ante ambigüedad.
- Verificar > confiar: nunca aceptar "listo" sin evidencia.
- Concreto > abstracto: ejemplos y datos en el prompt superan adjetivos.

## Relacionado
- [[fable-clon-skill]] (implementación completa), [[Diseño de Subagentes]], [[Fable 5 pago por uso]]
