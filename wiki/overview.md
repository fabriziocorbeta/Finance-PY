---
type: meta
title: "Overview del Sistema"
created: 2026-05-05
updated: 2026-05-05
tags: [meta, overview]
---

# Sistema — Overview

**Propietario:** Fabrizio  
**Modo:** Sistema Personal + Negocio + Second Brain  
**Creado:** 2026-05-05

## Propósito

Vault unificado que integra tres capas:
1. **Sistema Personal** — metas, áreas de vida, aprendizaje, recursos
2. **Base de Conocimiento del Negocio** — emprendimientos, decisiones, stakeholders, intel
3. **Second Brain** — síntesis, conexiones, contexto persistente entre sesiones

## Estructura

```
wiki/
├── emprendimientos/   proyectos y negocios activos
├── decisiones/        decisiones clave con rationale
├── stakeholders/      personas y empresas relevantes
├── intel/             mercado, competencia, tendencias
├── metas/             objetivos personales y profesionales
├── areas/             salud, finanzas, carrera, creativo
├── aprendizaje/       conceptos y skills en desarrollo
├── recursos/          libros, cursos, herramientas
└── meta/              dashboards y reportes de salud
```

## Convenciones

- Todo usa YAML frontmatter: type, status, created, updated, tags
- Wikilinks con `[[Nombre de Nota]]`
- `.raw/` contiene fuentes: nunca modificar
- `wiki/index.md` es el catálogo maestro
- `wiki/log.md` es append-only
- `wiki/hot.md` se actualiza al final de cada sesión

## Operaciones

- **Ingest:** drop en `.raw/`, decir "ingest [archivo]"
- **Query:** hacer cualquier pregunta, Claude lee index primero
- **Lint:** "lint the wiki" para health check
- **Save:** "/save" para archivar contexto de conversación
- **Research:** "/autoresearch [tema]" para investigación estructurada
