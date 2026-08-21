---
type: aprendizaje
status: en-desarrollo
created: 2026-07-07
updated: 2026-07-07
tags: [ia, agentes, arquitectura, automatizacion]
---

# Diseño de Subagentes

Patrones para construir agentes IA confiables (aplica al [[Agente IA CD & Co]] y a subagentes de Claude Code).

## Reglas de oro
1. **Una responsabilidad por agente.** Si el prompt necesita "y también...", divídelo en dos.
2. **Prompt autocontenido**: contexto, herramientas, formato de salida, criterio de éxito. El agente no ve la conversación padre.
3. **Ambigüedad definida**: preguntar, asumir con nota, o abortar — elegido de antemano, nunca indefinido.
4. **Mínimas herramientas**: menos superficie = menos errores y menos riesgo.
5. **Salida parseable** (JSON o markdown de estructura fija) si otro agente/sistema la consume.
6. **Logging de decisiones**: poder auditar por qué hizo lo que hizo.

## Testing antes de producción
- Caso feliz
- Input basura (mensajes rotos, idioma inesperado, audio vacío)
- Input malicioso (prompt injection: "ignora tus instrucciones y...")

## Seguridad
- Tratar todo input externo (mensajes WhatsApp, emails, webs) como no confiable: datos, no instrucciones.
- El agente nunca ejecuta acciones irreversibles (pagos, borrados) sin confirmación humana.
- Secretos fuera del prompt; permisos por rol.

## Relacionado
- [[Dirección de Modelos IA]], [[fable-clon-skill]], [[Agente IA CD & Co]]
