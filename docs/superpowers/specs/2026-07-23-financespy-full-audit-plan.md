---
title: "FinancePY — Plan de Auditoría Total (bugs + seguridad)"
created: 2026-07-23
status: plan-only-not-executed
---

# FinancePY — Plan de Auditoría Total

**Alcance confirmado con el usuario:** solo FinancePY (repo `cd-co-erp`, rama `main`). Queda afuera esta ronda: alejandro-agent (ya tuvo su propia auditoría puntual hoy, hallazgo crítico de `/webhook` resuelto) y CD & Co ERP (IDOR crítico ya resuelto semanas atrás, evaluar aparte si amerita).

**Esto es el PLAN, no la ejecución.** Nada de esto se corrió todavía.

## Por qué no arrancar de cero

Ya hay una auditoría de seguridad completa cerrada (2026-07-14/18, ver [[FinancePY — Auditoría de seguridad y code smells (75 hallazgos)]]): P0/P1 100% resueltos y verificados en prod (CORS allowlist, CSP enforce, rate-limit login, XSS sanitizado, registro cerrado). Repetir esas verificaciones desde cero sería desperdiciar tokens en algo ya confirmado — el plan abajo las trata como **baseline a re-confirmar rápido**, no a re-investigar desde cero.

Lo que SÍ es nuevo y no auditado todavía: todo el código de esta sesión (módulo Ventas completo, sync offline con IndexedDB/Background Sync, cambio de modelo del asistente IA, cambios de PWA/manifest/iconos). Esa es la prioridad real.

## Fase 1 — Superficie nueva de esta sesión (prioridad alta, no auditada aún)

| Área | Qué revisar | Por qué importa |
|---|---|---|
| `SalesController` (print/delivery_note/create JSON) | Scoping por `Current.family`, autorización en las 2 rutas nuevas de print, si el JSON de error filtra algo sensible | Rutas nuevas, nunca revisadas |
| Cola offline (`offline_sales_db.js`, `offline_sale_form_controller.js`, `service-worker.js` Background Sync) | `replayPendingSales()` reenvía `FormData` arbitrario a `/sales` desde el service worker — confirmar que solo puede haberse escrito ahí desde el mismo origen (requiere XSS previo para ser explotable, no es un vector nuevo por sí solo, pero verificar) | Único código que hace un POST autónomo sin interacción directa del usuario en el momento del envío |
| Migraciones nuevas (`delivery_address`, `delivery_date`, `carrier`) | Sin validación de longitud/formato en `delivery_address` (texto libre) — chequear XSS al renderizarlo en la nota de entrega/venta | Campo de texto libre nuevo, se imprime en 2 vistas |
| Cambio de modelo IA (`nemotron-3-nano-30b-a3b`) | Qué datos financieros reales viajan al endpoint de NVIDIA vía function-calling (montos, categorías, nombres de cuenta) — confirmar que es el mismo alcance de datos que ya viajaba antes (no un cambio de superficie, solo de proveedor) | Cambio de proveedor externo, aunque el patrón de envío de datos ya existía |
| Manifest/iconos/service-worker (fix splash + Android) | Bajo riesgo (assets estáticos públicos), pero confirmar que `CACHE_VERSION` bump no dejó clientes con service worker viejo sirviendo código stale de forma insegura | Cambios recientes, verificar que no rompió nada de seguridad al tocar el mismo archivo que la cola offline |

## Fase 2 — Re-confirmación rápida del baseline (bajo esfuerzo, ya resuelto antes)

No re-investigar desde cero — solo confirmar que sigue en pie:
- [ ] `CORS_ALLOWED_ORIGINS` sigue siendo allowlist real en prod (no wildcard)
- [ ] `CSP_REPORT_ONLY=false` (enforce) sigue activo
- [ ] `ONBOARDING_STATE=closed` sigue así
- [ ] Rate limiting (`rack-attack`) sigue activo en login
- [ ] Los 10 hallazgos de Brakeman ignorados siguen siendo los mismos 10 (no crecieron) — correr Brakeman real de nuevo, comparar conteo

## Fase 3 — Pasada OWASP fresca, sistema completo (esfuerzo medio)

Barrido general aunque ya se cubrió antes — código nuevo pudo introducir regresiones en áreas ya arregladas:
- SQL injection (interpolación en joins/where — ya se encontró 1 caso en `auto_transfer_matchable.rb`, confirmar que no hay otro nuevo)
- XSS (además de lo ya sanitizado, revisar las 2 vistas nuevas de impresión de Ventas)
- CSRF (confirmar que el JSON nuevo de `SalesController#create` no abre una vía de bypass del token — especialmente relevante porque el service worker hace `fetch` sin pasar por el flujo normal de formulario)
- Auth/authz (scoping por family en todas las rutas nuevas)
- Secretos hardcodeados (grep general, no solo en lo nuevo)
- Deserialización insegura, path traversal, SSRF (barrido general, baja probabilidad dado el stack)

## Fase 4 — Dependencias (nunca hecho para Ruby en este repo)

Se corrió `npm audit fix` en alejandro-agent hoy, pero **nunca se corrió un audit de gems de Ruby en FinancePY**. Pendiente real:
- [ ] `bundle exec bundler-audit check --update` (instalar la gem si no está) en el contenedor real de la VM (no local, por el mismo problema de Ruby 2.6 vs 3.4.7)
- [ ] Revisar `Gemfile.lock` por gems con CVEs conocidos

## Fase 5 — Bugs / correctness (no solo seguridad)

El pedido explícito incluye "bugs", no solo huecos de seguridad:
- [ ] Confirmar que los 3 hallazgos de la auditoría ERP de julio (stock negativo al completar venta, conversión de moneda inventario, movimientos de stock huérfanos al borrar) siguen resueltos — memoria dice que sí (PRs #35/36/37), spot-check rápido, no re-investigar de cero
- [ ] Edge cases de los campos nuevos: `delivery_date` en el pasado, `carrier` con caracteres raros, `quantity: 0` (ya cubierto por un test nuevo esta sesión, confirmar que el test realmente corre en el contenedor real)
- [ ] Race conditions en la cola offline: qué pasa si el usuario cierra la pestaña a mitad de un `replayPendingSales()` — ¿queda un registro en estado intermedio corrupto?
- [ ] Backoff/reintentos: confirmar que `MAX_SYNC_ATTEMPTS` realmente para de reintentar (no hay loop infinito si Background Sync dispara repetidas veces antes de que se actualice el contador)
- [ ] N+1 queries en las vistas nuevas de Ventas (`sale_items`, `product` — ya usa `.includes` en index, confirmar en print/delivery_note también)

## Cómo se va a verificar cada hallazgo (limitación de entorno conocida)

El test suite completo de Rails no corre ni localmente (Ruby 2.6 vs 3.4.7 requerido) ni siempre en el contenedor real (fixtures fallan por permisos de Supabase en algunos casos). Cada hallazgo de este audit se verifica por el método que realmente funcione, en este orden de preferencia:
1. Test acotado nuevo corrido en el contenedor real de la VM (`docker exec financespy-web-1 bin/rails test ...`)
2. `bin/rails runner` con datos reales para reproducir el comportamiento directamente
3. `curl` contra el sitio real para confirmar headers/respuestas
4. Lectura de código + `ruby -c`/`node --check` cuando lo anterior no aplica

## Orden de ejecución recomendado (para cuando se apruebe ejecutar)

1. Fase 1 (superficie nueva) — más barato y más valor, nada de esto se revisó nunca
2. Fase 2 (re-confirmar baseline) — rápido, da tranquilidad de que nada regresionó
3. Fase 4 (bundler-audit) — nunca se hizo, barato de correr
4. Fase 5 (bugs/correctness) — medio esfuerzo
5. Fase 3 (OWASP completo) — el más caro en tiempo/tokens, dejarlo para el final

## Qué NO incluye este plan (explícitamente fuera de alcance esta ronda)

- alejandro-agent y CD & Co ERP (confirmado con el usuario, quedan afuera)
- Migración a la PC local / Railway (proyecto de infra separado, no de código)
- El proyecto PWA offline-first en sí (ya se implementó y deployó, esto audita SU código, no lo re-diseña)
