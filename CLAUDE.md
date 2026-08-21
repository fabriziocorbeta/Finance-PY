## Approach
- Think before acting. Read existing files before writing code.
- Be concise in output but thorough in reasoning.
- Prefer editing over rewriting whole files.
- Do not re-read files you have already read unless the file may have changed.
- Skip files over 100KB unless explicitly required.
- Suggest running /cost when a session is running long to monitor cache ratio.
- Recommend starting a new session when switching to an unrelated task.
- Test your code before declaring done.
- No sycophantic openers or closing fluff.
- Keep solutions simple and direct.
- User instructions always override this file.

# Sistema — LLM Wiki

Mode: C + D (Business + Personal / Second Brain)
Purpose: Sistema personal integrado — emprendimientos, decisiones, metas, segunda mente
Owner: Fabrizio
Created: 2026-05-05

## Structure

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

## Wiki Knowledge Base

When you need context not already in this project:
1. Read `wiki/hot.md` first (contexto reciente, ~500 palabras)
2. If not enough, read `wiki/index.md` (catálogo completo)
3. If you need domain specifics, read `wiki/<domain>/_index.md`
4. Only then read individual wiki pages

## Conventions

- All notes use YAML frontmatter: type, status, created, updated, tags (minimum)
- Wikilinks use [[Note Name]] format: filenames are unique, no paths needed
- .raw/ contains source documents: never modify them
- wiki/index.md is the master catalog: update on every ingest
- wiki/log.md is append-only: never edit past entries
- New log entries go at the TOP of the file

## Operations

- Ingest: drop source in .raw/, say "ingest [filename]"
- Query: ask any question — Claude reads index first, then drills in
- Lint: say "lint the wiki" to run a health check
- Archive: move cold sources to .archive/ to keep .raw/ clean
