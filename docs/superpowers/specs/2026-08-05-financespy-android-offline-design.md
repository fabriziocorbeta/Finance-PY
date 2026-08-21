---
title: "App Android Offline-First — FinancePY"
created: 2026-08-05
status: approved
---

# App Android Offline-First — FinancePY

## Contexto y objetivo

El usuario quiere una versión de FinancePY instalable en Android vía Android Studio, con offline-first real: lectura y escritura en cualquier pantalla, no solo Ventas (que ya tiene offline parcial desde `docs/superpowers/specs/2026-07-23-financespy-pwa-offline-design.md`). Motivación doble: enmascarar la latencia geográfica actual (VM en Iowa), y — descubierto en el camino de esta misma conversación — el hosting de FinancePY está migrando de una VM GCP a una notebook Windows casera (ver `wiki/decisiones/FinancePY - Hosting fase prueba (PC local).md` del vault), con uptime estructuralmente peor que un cloud VM. Offline-first en el cliente se vuelve más importante, no menos, dado ese contexto — es la pieza que absorbe los cortes del server, no solo la distancia geográfica.

Estado actual: PWA mínima con offline **solo para crear Ventas** (`app/views/pwa/service-worker.js`, IndexedDB `pending_sales` + Background Sync `sale-sync`, idempotencia vía `client_request_id` + `Rails.cache`). El resto de la app (cuentas, transacciones, presupuestos, flujo de caja, metas) es 100% online-only hoy.

Este spec generaliza y reemplaza el alcance de ese documento anterior (que explícitamente dejaba "escritura offline en otros módulos" y "capa de datos cliente genérica (RxDB)" fuera de alcance como YAGNI en su momento — ese momento ya pasó).

Diseñado siguiendo `superpowers:brainstorming`, con investigación técnica corrida vía 5 agentes de research (TWA/Bubblewrap, Capacitor, arquitecturas de sync engine para stack Hotwire no-SPA, comportamiento de auth offline verificado contra el código real del repo, estrategia de resolución de conflictos) más un agente de síntesis — 562K tokens, ~70 tool calls, incluyendo lectura directa de archivos reales del repo (`fabriziocorbeta/cd-co-erp`) vía `gh api`, no solo memoria de entrenamiento.

## Hallazgo relevante (no accionado en este spec)

El repo tiene un stack completo y dormido: `app/models/mobile_device.rb` + `app/controllers/api/v1/auth_controller.rb` + Doorkeeper (`config/initializers/doorkeeper.rb`) — OAuth2 con token de 30 días + refresh, y una API JSON completa en `app/controllers/api/v1/` (accounts, transactions, categories, budgets, sync, chats). Heredado del fork de Sure Finance, construido para un cliente **Flutter** (`mobile/android/` trae `dev.flutter.flutter-gradle-plugin` y `sureapp://oauth/callback`) que el equipo original nunca shippeó. Funciona, nunca se usó.

Usar esto sería un proyecto distinto: un cliente nativo/JSON real, no "envolver la app Hotwire existente". Queda explícitamente fuera de alcance de este spec — si en el futuro se decide construir un cliente nativo de verdad en vez de un wrapper, este stack es el punto de partida obvio, pero es una decisión de arquitectura aparte que hay que tomar a propósito, no heredar sin darse cuenta.

## Alcance (confirmado con el usuario)

- **Offline read+write en toda la app** — cuentas, transacciones, presupuestos, flujo de caja, metas. No un subset como el spec de Ventas.
- **Ventana de lectura offline: ~90 días** de historial reciente (saldos actuales, transacciones y presupuesto del período en curso). Reportes anuales y búsqueda en todo el histórico requieren conexión.
- **Concurrencia esperada: rara.** Un solo dueño (con horizonte de expansión a SaaS en 6-12 meses, no inmediato) — no se diseña para edición concurrente real hoy.
- **Distribución: sideload hoy** (Android Studio / adb, sin Play Store), con intención declarada de publicar como SaaS/producto en 6-12 meses. La elección técnica de abajo no encierra ese camino.
- **Push nativo: sí, deseado en el corto/mediano plazo** — esto es lo que determinó la elección de empaquetado (ver siguiente sección).
- **Plataforma: Android únicamente.** iOS fuera de alcance explícito, consistente con la restricción ya establecida en `docs/superpowers/plans/2026-07-28-android-purchase-webhook.md`.

Fuera de alcance explícito (YAGNI):
- El stack Doorkeeper/API v1/Flutter dormido (sección anterior) — no se activa ni se construye un cliente nativo real sobre él.
- CRDTs, event sourcing, resolución automática de conflictos — sobre-ingeniería confirmada para este nivel de concurrencia.
- Multi-usuario concurrente real editando los mismos registros — si esto cambia, revisar el approach de conflictos (sección correspondiente).
- Cifrado at-rest de la DB local — riesgo real (dispositivo perdido/robado) señalado por la investigación pero no bloqueante para la v1; queda como mejora de seguridad a evaluar aparte.
- Timeout de sesión / revocar otras sesiones al cambiar password — la investigación encontró que la cookie de sesión hoy es efectivamente permanente (sin `expires_at`, sin job de limpieza) y que `PasswordsController#update` no revoca otras sesiones. Offline-first amplifica cuánto tiempo esa credencial queda válida en un dispositivo que se puede perder. Es una decisión de producto real, pero separada de este spec — se deja como pendiente explícito, no se resuelve acá.

## Approaches evaluados

Tres opciones completas salieron de la investigación (empaquetado + sync + auth + conflictos, cada una coherente de punta a punta):

1. **TWA + RxDB** — envolver la PWA existente vía Bubblewrap (es literalmente Chrome, comparte cookies/IndexedDB con el navegador del celular, cero infraestructura de servidor nueva). Descartada al final por el requisito de push nativo — TWA depende de Web Push, notoriamente poco confiable en Android con gestión de batería agresiva (Xiaomi/Huawei/etc.).
2. **Capacitor + PowerSync** — push nativo real, SQL real client-side, pero exige levantar y operar un servicio de sync nuevo (logical replication de Postgres) — justo el tipo de pieza frágil nueva que no conviene sumar cuando el server ya se muda a una máquina menos confiable.
3. **Capacitor + RxDB (elegida originalmente)** — combina las dos decisiones de forma independiente en vez de tomar un paquete cerrado: empaquetado nativo (push real, auth aislada) + motor de sync liviano sin infraestructura de servidor nueva. El research confirmó que packaging (TWA vs Capacitor) y sync engine (RxDB vs PowerSync vs otros) son ejes independientes — no hace falta elegir el combo "de fábrica".

**Ajuste posterior (2026-08-05, al empezar la implementación):** se mantiene Capacitor como empaquetado, pero **se descarta RxDB** por una restricción real del proyecto descubierta al verificar el entorno (no hay Node en el pipeline) — ver la sección de Sync más abajo. La arquitectura final es **Capacitor + IndexedDB propio**.

## Arquitectura elegida: Capacitor + IndexedDB propio (sin librería de sync)

### Empaquetado (Capacitor)

- `server.url` de Capacitor apuntando al origin real (`https://finance.cd-co.com.py` en prod, o el nuevo origin tras la migración a la notebook) — patrón documentado y de primera clase de Capacitor para apps server-renderizadas existentes, no un hack. El puente nativo (`window.Capacitor`) se inyecta igual en una página cargada remotamente.
- `npx cap add android` genera un proyecto Android Studio estándar (Gradle/AGP/Kotlin) — se abre directo en Android Studio, build normal.
- **Costo real asumido a propósito**: toolchain nativo paralelo (Node/npm + Gradle) permanente, separado del pipeline actual (Ruby+Docker puro). Es el precio de tener push nativo confiable — no hay forma de evitarlo eligiendo otra combinación.
- **Auth**: WebView de Capacitor tiene cookie jar propio y aislado (`/data/data/<package>/app_webview/`), separado del Chrome del sistema. Implica un login dentro de la app la primera vez (una sola vez, no un bug recurrente) — la cookie de sesión existente (`session_token`, firmada, permanente) funciona sin cambios una vez logueado ahí adentro.
- Push: FCM nativo vía plugin de Capacitor — pendiente de definir el trigger exacto (fin de sync, umbral de presupuesto cruzado) en el plan de implementación, no en este spec de arquitectura.

### Sync (IndexedDB propio, sin librería)

**Corregido 2026-08-05 durante la implementación — este spec originalmente especificaba RxDB.** Al empezar a ejecutar se verificó contra el entorno real que **el proyecto no tiene Node en ningún punto del pipeline**: no está en el host de la VM, ni en ninguna etapa del `Dockerfile` (los assets se compilan con `./bin/rails assets:precompile`, que funciona sin Node porque todo el JS va por **importmap** y Tailwind usa su binario standalone). El `package.json` existente sirve solo para Biome (linter, corre en CI con `setup-node`, nunca en el container). La investigación que recomendó RxDB no tenía ese dato.

Adoptar RxDB habría exigido meter una etapa de Node al Dockerfile — encareciendo justo el paso de build, que es el pico de memoria real, en la máquina que va a tener menos (notebook 8GB). Decisión del usuario: **extender el patrón IndexedDB hecho a mano que el proyecto ya usa**, en vez de introducir librería + toolchain.

- Módulos ES planos servidos por importmap, exactamente igual que el `app/javascript/services/offline_sales_db.js` que ya existe y funciona en producción para la cola offline de Ventas. Cero cambios en `Dockerfile`, `package.json` o el pipeline de assets.
- Dos stores IndexedDB: uno de lectura (cache de documentos sincronizados desde el server) y uno de escritura (`pending_writes`, cola de mutaciones pendientes) — a diferencia de RxDB, que unificaba ambos, acá son explícitamente dos mecanismos, cada uno simple.
- El protocolo contra el server no cambia respecto al diseño original: endpoints Rails planos de pull (paginado por checkpoint) y push (idempotente por UUID de cliente). **No se requiere logical replication de Postgres ni un daemon de sync separado** — sigue siendo la razón de no elegir PowerSync.
- Orden sugerido: transacciones primero (mayor valor offline), después cuentas/presupuestos/metas.
- Costo asumido: ~200-300 líneas propias de lógica de sync (checkpoint, replay, dedupe) que RxDB habría dado hecha. Es la objeción original de la investigación, aceptada a conciencia a cambio de no tocar el pipeline de build.
- Las agregaciones del dashboard de flujo de caja se resuelven en JS sobre los documentos locales (misma limitación que tenía la opción RxDB con storage IndexedDB — no cambia con esta decisión).

### Auth

- Se reusa la cookie de sesión existente (`cookies.signed.permanent[:session_token]`, `Session` ActiveRecord sin expiración) sin cambios de backend. Verificado contra el código real: ni la cookie ni el registro `Session` expiran solos — el mecanismo que ya prueba esto en producción es el propio flujo offline de Ventas (`fetch('/sales', { credentials: 'same-origin' })` sobreviviendo cortes de conexión).
- Con Capacitor, ese login ocurre una vez dentro del WebView aislado de la app (no comparte el Chrome del sistema) — UX de "iniciar sesión la primera vez que abrís la app", no recurrente.
- Pendiente explícito de producto (fuera de este spec, señalado en "Fuera de alcance"): decidir si la sesión efectivamente-infinita actual es aceptable ahora que un dispositivo la va a sostener offline por períodos largos a propósito.

### Conflictos

Dos mecanismos distintos y deliberadamente separados — no se fuerza uno solo a cubrir ambos casos:

1. **Creates** (transacción nueva, aporte a meta, línea de presupuesto): se generaliza el patrón ya probado en producción para Ventas — UUID generado client-side (`client_request_id` vía `crypto.randomUUID()`), encolado en un store IndexedDB genérico `pending_writes` (campos: `local_id`, `entity_type`, `action`, `entity_id` nullable, `base_lock_version` nullable, `payload`, `queued_at` — secuencia local, no timestamp de reloj del dispositivo, para evitar problemas de reloj desincronizado). El server dedupea vía `Rails.cache` antes de insertar, igual que hoy en `SalesController#create`.
2. **Edits a registros existentes** (cambiar categoría, ajustar presupuesto, editar aporte de meta): columna `lock_version` nativa de Rails (`ActiveRecord::Locking::Optimistic`) en las tablas editables por el usuario (transacciones, presupuestos, metas) — **no** en tablas derivadas/calculadas (saldos, tipos de cambio, holdings), ahí no hay nada que pueda chocar. `ActiveRecord::StaleObjectError` no se traga silenciosamente: se expone al cliente como "necesitás resolver esto" — un banner simple con elegir "mi versión" o "la del servidor", sin UI de diff ni auto-merge, justificado porque la frecuencia real esperada de choques es casi cero.
3. **Verificar antes de implementar**: confirmar si algún modelo ya trae `lock_version` heredado del fork de Sure antes de agregar la migración (no confirmado en esta investigación, revisar `db/schema.rb` real).

## Manejo de errores

- Reintentos con backoff (mismo patrón ya usado en Ventas: base 5s, tope 60s, máximo 5 intentos automáticos) antes de exponer un item como "necesita revisión manual" en vez de reintentar indefinidamente o perderlo en silencio.
- Background Sync (donde aplique) es best-effort — Doze/App Standby y gestores de batería agresivos de fabricantes Android pueden demorar el reintento más allá de "apenas vuelve la conexión". No es un bug del diseño, es una limitación de la plataforma que hay que comunicar en la UI (indicador "sincronizado hace Xm", no una promesa de tiempo real).
- `StaleObjectError` en edits: nunca se descarta el cambio local silenciosamente — siempre se le muestra al usuario y se le pide una decisión explícita.

## Testing

- Sin entorno Ruby local funcional (limitación conocida del proyecto) — verificación en el container Docker de la VM/notebook, igual que el resto del proyecto.
- Modo avión en dispositivo real (no solo DevTools, dado que esta vez el target es la app empaquetada, no el navegador) → crear/editar transacciones de varios tipos → reconectar → confirmar sync correcto sin duplicados.
- Forzar backgrounding/Doze real en un dispositivo Android físico antes de asumir que el timing de sync observado en desarrollo se sostiene en uso real — la investigación señaló esto explícitamente como no verificado, solo argumentado por arquitectura.
- Casos de `StaleObjectError`: editar el mismo registro offline y online a propósito, confirmar que el banner de conflicto aparece y que ninguna de las dos versiones se pierde antes de que el usuario elija.
- Confirmar que el login dentro del WebView aislado de Capacitor persiste correctamente entre reinicios de la app (no solo dentro de la misma sesión de uso).

## Notas de implementación

- No se toca la arquitectura Rails/Turbo/Hotwire para las pantallas que se quedan online-only — esto se agrega como una capa nueva sobre las pantallas que sí se llevan a offline-first, no un reemplazo del modelo de renderizado server-side existente.
- Extender (no reescribir) el patrón de idempotencia ya probado de Ventas para el nuevo store `pending_writes` genérico.
- Shippeable de forma incremental, pantalla por pantalla — no requiere un big-bang. Orden sugerido: transacciones + flujo de caja primero.
- Este spec asume que la migración de hosting a la notebook (vault: `FinancePY - Hosting fase prueba (PC local)`) sigue su curso normal — **pausada al momento de escribir este spec**, evaluada una alternativa Tailscale/multi-dispositivo y no adoptada. Ninguna decisión de este documento depende de qué opción de hosting se termine ejecutando; el diseño offline-first es igual de válido apuntando a la VM GCP actual, a la notebook, o a cualquier origin futuro — es precisamente el punto de ser offline-first.
