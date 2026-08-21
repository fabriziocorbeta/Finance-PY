---
type: emprendimiento
title: "FinancePY — entorno dev local bloqueado en Mac"
status: bloqueado
created: 2026-08-05
updated: 2026-08-05
tags: [emprendimiento, financepy, dev-environment, ruby, postgres, docker]
related:
  - "[[FinancePY]]"
---

# FinancePY — entorno dev local bloqueado en Mac

Repo clonado en `~/code/financespy`, pero no se puede levantar el servidor Rails local en este Mac (2026-08-05). Intento fue disparado al pedir previsualizar la app en vista iPhone — sin proyecto Xcode (FinancePY es Rails web, no app nativa iOS), la vía elegida fue simular viewport de iPhone en browser contra prod, no local.

## Bloqueadores encontrados

- **Ruby version mismatch**: sistema trae Ruby 2.6.10 (`/System/Library/Frameworks/Ruby.framework`), pero `Gemfile.lock` requiere bundler 2.6.7 — falla `bundle check` con `Gem::GemNotFoundException`. Repo tiene `.ruby-version` propio, sugiere que falta rbenv/rvm con la versión correcta instalada y activa.
- **Sin bundler instalado** para esa versión de Ruby.
- **Sin Postgres local corriendo**: `pg_isready` no existe en el PATH. `config/database.yml` espera Postgres en `127.0.0.1:5432`, DB dev `sure_development`.
- **Docker Desktop no estaba corriendo**: `docker info` falla. `compose.local.yml` existe como alternativa, pero apunta al MISMO `DATABASE_URL` de Supabase que prod (no hay Postgres aislado para esta PC) — no es un entorno de prueba realmente separado, ver advertencia en el propio archivo.

## Camino recomendado si se retoma

1. Instalar Ruby correcto vía rbenv (leer `.ruby-version` del repo) + `gem install bundler`.
2. Instalar y levantar Postgres local (`brew install postgresql`), crear `sure_development`.
3. `bundle install`, `bin/rails db:setup`, generar `SECRET_KEY_BASE`.
4. Alternativa más rápida pero con caveat: prender Docker Desktop y usar `compose.local.yml` — pero comparte DB con prod (Supabase), no aislado.

## Decisión tomada esta sesión

No se invirtió tiempo en armar el entorno — se usó `https://finance.cd-co.com.py` directo en browser resizeado a 375×812 para ver la vista mobile. Suficiente para el pedido puntual (ver cómo luce en iPhone), no reemplaza tener dev local andando.
