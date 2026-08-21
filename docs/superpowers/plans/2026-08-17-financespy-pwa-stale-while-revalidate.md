# PWA Stale-While-Revalidate (FinancePY) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer que las navegaciones internas de Turbo Drive en FinancePY sirvan desde cache al toque (stale-while-revalidate), con invalidación activa tras mutaciones, sin tocar el comportamiento ya existente de cold-open ni de formularios.

**Architecture:** Tres bloques nuevos dentro del `fetch` listener ya existente de `app/views/pwa/service-worker.js` — ninguna infraestructura nueva, ningún archivo nuevo. Un cache adicional (`SWR_CACHE`) separado de los dos que ya existen (`CACHE_VERSION` para assets fingerprinted, `RUNTIME_CACHE` para cold-open).

**Tech Stack:** Service Worker API nativo (Cache Storage, fetch event), sin librerías. Rails 7.2 + Turbo Drive del lado servidor (sin cambios ahí).

## Global Constraints

- Spec fuente: `docs/superpowers/specs/2026-08-17-financespy-pwa-stale-while-revalidate-design.md` (status: approved).
- El repo FinancePY vive SOLO en una máquina remota, sin filesystem local: `ssh -o BatchMode=yes fabrizio@100.105.31.71`, repo en `~/financespy` (ruta absoluta `/home/fabrizio/financespy`), branch `main`. Todo comando de git/edición corre vía SSH.
- Producción real corre en Docker (`compose.local.yml` + `.env.local`) en esa misma máquina, sirviendo `https://finance.cd-co.com.py` vía Cloudflare Tunnel + Caddy. No hay entorno de staging — cualquier deploy es directo a producción.
- **No desplegar código a medio terminar.** Los 3 bloques (constantes, branch SWR, branch de invalidación) se implementan y commitean por separado, pero el deploy a producción se hace una sola vez al final (Task 4), con los 3 juntos — desplegar SWR sin invalidación dejaría usuarios viendo datos stale después de guardar, sin forma de que se autocorrija hasta la próxima visita.
- **No hay suite de tests automatizada para el service worker en este proyecto** (confirmado en el spec). Verificación de sintaxis vía `node --check` remoto en cada task de código. Verificación funcional real es 100% manual, hecha por el usuario en su dispositivo — no se puede automatizar porque requiere sesión autenticada real de la app (no se debe ni se puede loguear en la app con las credenciales del usuario para testear, eso está fuera de lo que un agente puede hacer).
- Este cambio es puramente Ruby/JS del lado servidor. **No requiere rebuild del APK Android** — el wrapper Capacitor solo carga la URL remota (`capacitor.config.json` → `server.url`), así que el fix llega solo la próxima vez que el WebView pida el service worker, sin reinstalar nada en el teléfono.
- Patrón de edición remota (usar en todo Task que edite código): reemplazo exacto de string vía Python por SSH, no hay Edit tool remoto disponible.

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/views/pwa/service-worker.js')
old = '''<OLD_STRING>'''
new = '''<NEW_STRING>'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

Si el `assert` falla, el archivo cambió respecto a lo que este plan asume — parar y releer el archivo remoto antes de continuar.

---

### Task 1: Constantes y helper (sin cambio de comportamiento)

**Files:**
- Modify: `app/views/pwa/service-worker.js:2` (agregar constante), `:36-46` (activate cleanup), `:20-22` (agregar helper después de `isCacheableAsset`)

**Interfaces:**
- Produce: constante `SWR_CACHE` (string `'swr-v1'`) y función `isTurboVisit(request)` (retorna boolean) — consumidos por Task 2.

- [ ] **Step 1: Agregar la constante `SWR_CACHE`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/views/pwa/service-worker.js')
old = '''const CACHE_VERSION = 'v5';
const RUNTIME_CACHE = 'runtime-v1';'''
new = '''const CACHE_VERSION = 'v5';
const RUNTIME_CACHE = 'runtime-v1';
const SWR_CACHE = 'swr-v1';'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```
Expected output: `OK`

- [ ] **Step 2: Agregar el helper `isTurboVisit` después de `isCacheableAsset`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/views/pwa/service-worker.js')
old = '''function isCacheableAsset(pathname) {
  return CACHEABLE_ASSET_PATTERNS.some((pattern) => pattern.test(pathname));
}'''
new = '''function isCacheableAsset(pathname) {
  return CACHEABLE_ASSET_PATTERNS.some((pattern) => pattern.test(pathname));
}

// Turbo Drive navega entre pantallas con fetch() normal, no con una
// navegacion de browser real -- event.request.mode nunca es 'navigate'
// para estos requests, asi que el branch de cold-open no los ve. Se
// identifican por el Accept header que Turbo manda en sus visitas.
function isTurboVisit(request) {
  const accept = request.headers.get('Accept') || '';
  return accept.includes('text/html') || accept.includes('text/vnd.turbo-stream.html');
}'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```
Expected output: `OK`

- [ ] **Step 3: Agregar `SWR_CACHE` a la lista protegida del cleanup en `activate`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/views/pwa/service-worker.js')
old = '''          if (cacheName !== CACHE_VERSION && cacheName !== RUNTIME_CACHE) {
            return caches.delete(cacheName);
          }'''
new = '''          if (cacheName !== CACHE_VERSION && cacheName !== RUNTIME_CACHE && cacheName !== SWR_CACHE) {
            return caches.delete(cacheName);
          }'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```
Expected output: `OK`

- [ ] **Step 4: Verificar sintaxis**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'node --check ~/financespy/app/views/pwa/service-worker.js && echo SYNTAX_OK'
```
Expected output: `SYNTAX_OK`

- [ ] **Step 5: Commit**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add app/views/pwa/service-worker.js && git commit -m 'feat: agregar cache SWR y helper de deteccion de visitas Turbo

Sin cambio de comportamiento todavia -- el cache y el helper quedan
declarados pero sin usar, preparando el branch de stale-while-revalidate
del siguiente commit.'"
```
Expected output: commit hash line ending in `main <hash>` (or similar), no errors.

---

### Task 2: Branch stale-while-revalidate para navegaciones Turbo

**Files:**
- Modify: `app/views/pwa/service-worker.js` (dentro del listener `fetch`, después del branch cache-first de assets, antes del branch de `OFFLINE_ASSETS`)

**Interfaces:**
- Consume: `SWR_CACHE`, `isTurboVisit(request)` (Task 1), `isCacheableAsset(pathname)` (ya existente).
- Produce: comportamiento SWR activo para GETs internos de Turbo — no expone nada nuevo a otros tasks.

- [ ] **Step 1: Insertar el branch SWR**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/views/pwa/service-worker.js')
old = '''  // Handle offline assets (logo, etc.)
  if (OFFLINE_ASSETS.some(asset => url.pathname === asset)) {'''
new = '''  // Stale-while-revalidate para navegaciones Turbo Drive (cambiar de
  // pantalla con la app ya abierta). Sirve la ultima version cacheada al
  // toque -- sin distincion visual entre stale y fresco, decision
  // confirmada en el spec -- mientras revalida en background siempre,
  // dejando el cache listo para la PROXIMA visita a esa misma pantalla
  // (la visita actual nunca espera a la revalidacion).
  if (event.request.method === 'GET' &&
      url.origin === self.location.origin &&
      event.request.mode !== 'navigate' &&
      !isCacheableAsset(url.pathname) &&
      isTurboVisit(event.request)) {
    event.respondWith(
      caches.open(SWR_CACHE).then((cache) =>
        cache.match(event.request).then((cached) => {
          const revalidate = fetch(event.request).then((response) => {
            if (response.ok) cache.put(event.request, response.clone());
            return response;
          });
          return cached || revalidate;
        })
      )
    );
    return;
  }

  // Handle offline assets (logo, etc.)
  if (OFFLINE_ASSETS.some(asset => url.pathname === asset)) {'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```
Expected output: `OK`

- [ ] **Step 2: Verificar sintaxis**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'node --check ~/financespy/app/views/pwa/service-worker.js && echo SYNTAX_OK'
```
Expected output: `SYNTAX_OK`

- [ ] **Step 3: Commit**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add app/views/pwa/service-worker.js && git commit -m 'feat: stale-while-revalidate para navegaciones Turbo Drive

Las visitas internas de Turbo (mode !== navigate) ahora se sirven desde
SWR_CACHE al instante cuando ya existe una version cacheada, revalidando
siempre en background para la proxima visita. Primera visita a una
pantalla sigue esperando a la red -- no hay nada que servir todavia.

Deploy pendiente hasta el commit de invalidacion (siguiente task) para
no exponer stale-forever sin forma de autocorregirse.'"
```
Expected output: commit hash, no errors.

---

### Task 3: Invalidación del cache SWR tras mutaciones exitosas

**Files:**
- Modify: `app/views/pwa/service-worker.js` (dentro del listener `fetch`, como PRIMER branch, inmediatamente después de `const url = new URL(event.request.url);`)

**Interfaces:**
- Consume: `SWR_CACHE` (Task 1).
- Produce: invalidación automática — cierra el ciclo de frescura para Task 2, sin exponer nada nuevo.

- [ ] **Step 1: Insertar el branch de invalidación como primer branch del listener**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/views/pwa/service-worker.js')
old = '''self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Handle navigation requests'''
new = '''self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Invalida el cache SWR despues de cualquier escritura exitosa, para que
  // la proxima pantalla de lectura visitada por Turbo refleje el cambio de
  // inmediato en vez de esperar su propia revalidacion en background. El
  // submit en si nunca se toca -- siempre va a red igual que antes, solo
  // se inspecciona la respuesta para decidir si limpiar el cache.
  if (['POST', 'PATCH', 'PUT', 'DELETE'].includes(event.request.method) &&
      url.origin === self.location.origin) {
    event.respondWith(
      fetch(event.request).then((response) => {
        if (response.ok) caches.delete(SWR_CACHE);
        return response;
      })
    );
    return;
  }

  // Handle navigation requests'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```
Expected output: `OK`

- [ ] **Step 2: Verificar sintaxis**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'node --check ~/financespy/app/views/pwa/service-worker.js && echo SYNTAX_OK'
```
Expected output: `SYNTAX_OK`

- [ ] **Step 3: Commit**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add app/views/pwa/service-worker.js && git commit -m 'feat: invalidar cache SWR tras mutaciones exitosas

Cierra el ciclo de stale-while-revalidate: POST/PATCH/PUT/DELETE
exitosos (2xx) contra el mismo origen borran SWR_CACHE completo. La
proxima pantalla visitada lo repuebla sola, entrada por entrada -- sin
invalidacion selectiva por simplicidad (decision del spec).'"
```
Expected output: commit hash, no errors.

---

### Task 4: Push, deploy y verificación manual del usuario

**Files:** ninguno (deploy + verificación, sin más cambios de código)

**Interfaces:** N/A — task de cierre.

- [ ] **Step 1: Push a `main`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'cd ~/financespy && git push origin main'
```
Expected output: `main -> main` sin errores de rechazo.

- [ ] **Step 2: Rebuild y redeploy del servicio `web`**

Solo `web` — el service worker es servido por el proceso Rails que atiende HTTP; `worker` (Sidekiq) no lo toca.

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'cd ~/financespy && docker compose -f compose.local.yml --env-file .env.local up -d --build web'
```
Expected output: termina con el container `financespy-web-1` en estado `Started` o `Running`, sin trace de error de build.

- [ ] **Step 3: Confirmar que el container levantó sano**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'sleep 5 && curl -sk -o /dev/null -w "%{http_code}\n" https://finance.cd-co.com.py'
```
Expected output: `302` (redirect normal a login, mismo comportamiento que antes del cambio — un 502 acá significa que el container no levantó bien, parar y revisar `docker logs financespy-web-1 --tail 50`).

- [ ] **Step 4: Confirmar que el archivo servido en producción tiene el cambio**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'docker exec financespy-web-1 grep -c "SWR_CACHE" ~/../rails/app/views/pwa/service-worker.js 2>/dev/null || docker exec financespy-web-1 sh -c "grep -c SWR_CACHE /rails/app/views/pwa/service-worker.js"'
```
Expected output: un número mayor a 0 (aparece varias veces: la constante, el branch SWR, el branch de invalidación, el cleanup de activate).

- [ ] **Step 5: Pedirle al usuario la verificación manual (no automatizable — requiere su sesión autenticada real en su propio dispositivo)**

Este paso no lo ejecuta el agente. Comunicarle al usuario, literal, los 4 escenarios del spec (`docs/superpowers/specs/2026-08-17-financespy-pwa-stale-while-revalidate-design.md`, sección Testing):

1. Abrir Transacciones dos veces seguidas → la segunda apertura debe pintar sin loader/delay visible.
2. Crear una transacción nueva → volver a Transacciones → debe aparecer sin re-tocar nada.
3. Modo avión, tras haber visitado Transacciones y Cuentas al menos una vez con red → ambas deben servir desde cache, no caer al offline.html genérico.
4. Modo avión, en una pantalla nunca antes visitada → mismo comportamiento que tenía antes de este cambio (sin regresión).

Esperar confirmación del usuario antes de considerar la feature cerrada. Si algo falla, volver a Task correspondiente (no hay rollback automático — el fix es otro commit + otro deploy, mismo ciclo).

---

## Self-Review

**Cobertura del spec:** constante+helper (Task 1) → branch SWR de navegación (Task 2) → invalidación post-mutación (Task 3) → deploy + los 4 escenarios de testing del spec (Task 4). Los edge cases del spec (sin red y sin cache, Turbo Streams parciales, cache viejo de deploy anterior, mutación sin re-navegar) no requieren código propio — ya quedan cubiertos por el comportamiento natural de las tres piezas (documentado así en el spec, no hace falta un task aparte).

**Placeholders:** ninguno — cada step tiene el comando/código real y su output esperado real.

**Consistencia de tipos/nombres:** `SWR_CACHE` e `isTurboVisit` se declaran en Task 1 y se usan sin cambios de nombre en Tasks 2 y 3. Verificado.
