---
type: session
title: "Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)"
created: 2026-08-05
updated: 2026-08-08
tags: [financespy, android, offline-first, capacitor, sesion]
status: entregado, con contradicción sin resolver
related:
  - "[[FinancePY — APK Android (TWA) con Bubblewrap]]"
  - "[[financespy]]"
  - "[[FinancePY - Hosting fase prueba (PC local)]]"
---

# Sesión 2026-08-05 — FinancePY offline-first Fase 1 (Capacitor)

## ⚠️ Contradicción con sesiones posteriores — leer primero

Esta sesión eligió **Capacitor** como shell nativo (por push FCM real). Una
sesión posterior (2026-08-06/07) construyó y firmó el APK con
**TWA/Bubblewrap** en su lugar — ver [[FinancePY — APK Android (TWA) con Bubblewrap]].
El trabajo de Capacitor de esta sesión (rama `feature/android-offline-phase1`
en GitHub, nunca mergeada) sigue siendo válido como **capa de datos offline**
(los endpoints Rails y el cliente IndexedDB no dependen de qué shell nativo
se use), pero el empaquetado en sí quedó descartado de hecho, no por decisión
explícita. **Al retomar: decidir a propósito** si el shell final es TWA (ya
construido, firmado, funcionando) o si vale la pena migrar a Capacitor por el
push nativo — no asumir ninguno de los dos sin confirmar.

## Qué se pidió

App Android instalable, offline-first (lectura y escritura en cualquier
pantalla), motivado por enmascarar la latencia y por la migración de hosting
a una máquina menos confiable que una VM cloud (esa migración se manejó en
paralelo en la misma sesión — ver [[FinancePY - Hosting fase prueba (PC local)]]).

## Proceso: brainstorming → spec → plan → ejecución

Investigación técnica real (5 agentes en paralelo + síntesis, 562K tokens):
TWA/Bubblewrap vs Capacitor, arquitectura de sync para un stack Rails/Hotwire
que NO es SPA, comportamiento de auth offline verificado contra el código
real del repo (vía `gh api`, no memoria), estrategia de resolución de
conflictos para una app financiera de bajísima concurrencia.

**Hallazgo grande de esa investigación**: el repo tiene un stack OAuth2
completo y dormido (`Doorkeeper` + `Api::V1::*` + `MobileDevice`), heredado
del fork de Sure Finance, construido para un cliente **Flutter** que nunca se
shippeó (`mobile/android/` trae literalmente `dev.flutter.flutter-gradle-plugin`).
Funciona, nunca se usó. Quedó fuera de alcance a propósito — activarlo sería
un cliente nativo real sobre JSON, no envolver la app Hotwire existente.

**Decisión tomada en esa sesión (ver contradicción arriba)**: Capacitor sobre
TWA, específicamente porque el usuario pidió push nativo confiable (Web Push
es poco confiable en Android con gestión de batería agresiva). Sync engine:
RxDB (no PowerSync) para no sumarle al server, que ya se estaba mudando a una
máquina menos confiable, un servicio de logical replication propio.

Spec: `docs/superpowers/specs/2026-08-05-financespy-android-offline-design.md`
Plan (Fase 1, alcance recortado a transacciones: lectura 90 días + creación,
sin edición): `docs/superpowers/plans/2026-08-05-financespy-android-offline-phase1.md`

## Qué se construyó y verificó (Fase 1 — transacciones, sin edición)

Rama `feature/android-offline-phase1` en `fabriziocorbeta/cd-co-erp` (**recién
pusheada a GitHub el 2026-08-08** — vivía sin pushear en un worktree de
`alejandro-vm`, que se apagó por la migración de hosting antes de mergear;
se prendió la VM un momento para rescatarla, ver sección de abajo).

- `GET /sync/transactions` — pull paginado por checkpoint, scopeado a la
  familia y cuentas accesibles, ventana de 90 días. 8 tests / 39 assertions.
- `POST /sync/transactions/push` — solo creates, idempotente (el ID lo genera
  el cliente, UUID), rechaza cuentas ajenas sin abortar el resto del lote.
- IndexedDB (sin librería — el proyecto no tiene bundler más allá de esbuild
  agregado en esta sesión, importmap para todo lo demás): cache de lectura,
  cola de escrituras pendientes, meta (checkpoint + cuentas).
- Stimulus: online deja la vista server-rendered intacta; offline la
  reemplaza por lista cacheada + form de alta.
- Config de Capacitor (modo remoto, `server.url` al dominio real, no IP —
  para sobrevivir a la migración de hosting sin rebuild) commiteada y lista
  para `npx cap add android`, pero **nunca se corrió** — necesita Android
  Studio en la máquina del usuario, fuera del alcance de lo que se pudo
  hacer en esta sesión.

**Verificado en vivo, sin escribir en producción** (condición acordada
explícitamente porque el stack de desarrollo compartía el `DATABASE_URL` de
Supabase con prod): cache poblado con 74 transacciones reales (coincide
exacto con el total real de la UI), render offline correcto, alta encolada
con UUID propio, cero POSTs al endpoint de push y cero filas de prueba
confirmado en los logs y en la DB real tras la prueba.

## Errores propios corregidos en el camino (para no repetir)

- **CSP nonce**: iba a agregar un `<script>` crudo para el bundle nuevo —
  CSP enforce está activo en este proyecto, se hubiera bloqueado en
  silencio, exactamente el mismo bug que se arregló en prod más temprano
  la misma sesión (nonce vacío en `content_security_policy_nonce_generator`).
  Corregido antes de ejecutar, usando `javascript_include_tag ..., nonce: true`.
- **`includes(:transaction)` no existe** como asociación real —
  `delegated_type` solo da el método de lectura `entry.transaction`, no algo
  eager-loadable. Todo el codebase usa `includes(:entryable)`. Corregido al
  correr los tests, no asumido de entrada.
- **Casi corro `bin/rails test` contra producción real**: `DATABASE_URL` es
  una sola variable global que Rails aplica a todo `RAILS_ENV`, y
  `db:test:prepare` dropea la base — ya tumbó producción una vez el
  2026-07-28 (documentado en el propio `compose.prod.yml`). Se armó un
  servicio `test-db`/`test-runner` aislado (profile `test`) en el compose
  del worktree y se verificó explícitamente el `DATABASE_URL` real antes de
  correr un solo test.
- **Mounts de Docker montando `./app` entero**: dejaba `app/assets/builds/`
  de solo lectura para el uid del container (host uid 1001, container uid
  1000) → `assets:precompile` moría con `EACCES`. Corregido a mounts
  dirigidos (`controllers/`, `javascript/`, `views/` nada más).
- **Versiones de Capacitor verificadas contra el registry real de npm**
  (8.5.0) en vez de escribir `^7` de memoria, que hubiera estado mal.

## Recuperación del trabajo (2026-08-08, fuera de la sesión original)

Al retomar para hacer `/save`, la hot cache reveló que el hosting ya había
migrado (VM apagada). Los 5 commits de esta sesión vivían solo en un
worktree local de esa VM, nunca pusheados (esperaba aprobación explícita del
usuario antes de tocar `main`, coherente con el resto de la sesión). El
disco de la VM seguía intacto (`TERMINATED`, no borrado) — se prendió la VM,
se pusheó la rama a GitHub, se confirmó que solo revivieron los containers
viejos de prod (no el stack de prueba), y se apagó de nuevo. **Nada quedó
corriendo indefinidamente ni se tocó la migración ya hecha.**

## Pendiente real

- [ ] **Decidir TWA vs Capacitor a propósito** (ver contradicción arriba) —
  no seguir de largo con ninguno de los dos sin resolverlo explícitamente
- [ ] Mergear `feature/android-offline-phase1` a `main` — pendiente de
  revisión y aprobación del usuario, nunca se hizo
- [ ] Fase 2 (fuera de esta sesión, documentada como próximo paso en el plan):
  edición offline de transacciones — necesita `lock_version` +
  `ActiveRecord::StaleObjectError` + selector de categoría offline
- [ ] Fase 3: flujo de caja/dashboard offline (agregaciones)
- [ ] Push nativo (razón de elegir Capacitor en primer lugar) — no
  implementado en Fase 1, requiere proyecto Firebase + definir el trigger real
