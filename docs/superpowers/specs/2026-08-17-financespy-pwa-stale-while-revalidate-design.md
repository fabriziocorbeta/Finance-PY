---
title: "PWA Stale-While-Revalidate para navegación — FinancePY"
created: 2026-08-17
status: approved
related:
  - "docs/superpowers/specs/2026-07-23-financespy-pwa-offline-design.md"
---

# PWA Stale-While-Revalidate para navegación — FinancePY

## Contexto y objetivo

Sobre la base offline-first ya implementada (ver [[2026-07-23-financespy-pwa-offline-design]]), el usuario quiere "maquillar" los tiempos de carga percibidos dentro de la app — que abrir y navegar se sienta instantáneo, más cerca de una app nativa, sin depender de la latencia real del hosting (notebook local en Paraguay detrás de Cloudflare Tunnel).

Estado actual del service worker (`app/views/pwa/service-worker.js`):
- Cache-first para assets fingerprinted (JS/CSS/fonts/iconos) — ya instantáneo.
- Network-first con fallback a cache para navegaciones (`event.request.mode === 'navigate'`) — solo cubre aperturas en frío / recargas duras.
- IndexedDB + background sync para ventas creadas offline.

**Hallazgo del brainstorming:** la app usa Turbo Drive (`turbo-rails` gem). Las navegaciones internas (click en un link, cambiar de Transacciones a Cuentas) NO disparan `event.request.mode === 'navigate'` — Turbo las hace como `fetch()` normales con `Accept: text/vnd.turbo-stream.html, text/html`. El branch de navegación actual del service worker no cubre estas requests en absoluto; hoy van directo a red sin ninguna estrategia de cache aplicada.

## Alcance (confirmado con el usuario)

- Aplica **stale-while-revalidate (SWR)** a las navegaciones Turbo (GET, mismo origen, pantallas de lectura: balances, listas de transacciones, reportes, cuentas).
- Tolerancia de frescura confirmada: sin distinción visual entre dato cacheado y dato fresco — el usuario acepta ver un valor "de la visita anterior" por un instante, sin loader ni indicador de "actualizando".
- **Formularios (crear/editar) quedan fuera de SWR, network-first estricto** — nunca se sirven desde cache, siempre esperan confirmación real del servidor antes de mostrar éxito. Ya cubierto naturalmente porque son POST/PATCH/PUT/DELETE y SWR solo aplica a GET.
- **Invalidación activa post-mutación:** tras un submit exitoso (2xx), se borra el cache SWR completo, para que la próxima pantalla de lectura visitada refleje el cambio de inmediato en vez de esperar "una visita más" para autocorregirse.

Fuera de alcance explícito (YAGNI):
- Indicador visual de "dato desactualizándose" — el usuario explícitamente no lo quiere.
- Invalidación selectiva por tipo de recurso (ej. solo invalidar `/transactions` tras crear una transacción, dejando `/reports` intacto) — se invalida todo el cache SWR por simplicidad; se repuebla solo, pantalla por pantalla, a medida que el usuario navega.
- Cambios a la estrategia de `navigate`-mode (cold-open) ya definida en el spec anterior — sigue siendo network-first con fallback a cache, sin cambios.
- Optimistic UI en formularios.

## Arquitectura

Extiende el service worker existente (mismo archivo, sin nueva infraestructura). Un cache nuevo, `SWR_CACHE`, separado de `RUNTIME_CACHE` (que sigue siendo exclusivo del branch `navigate`) y de `CACHE_VERSION` (assets fingerprinted).

### Detección de requests Turbo

Dentro del listener `fetch` existente, nuevo branch antes del fallback final, con esta condición:
- `event.request.method === 'GET'`
- `url.origin === self.location.origin`
- `event.request.mode !== 'navigate'` (esas ya las cubre el branch existente)
- no matchea `isCacheableAsset` (esas ya las cubre el branch cache-first existente)
- header `Accept` de la request contiene `text/html` o `text/vnd.turbo-stream.html`

### Estrategia SWR

```js
if (isTurboVisit(event.request)) {
  event.respondWith(
    caches.open(SWR_CACHE).then((cache) =>
      cache.match(event.request).then((cached) => {
        // Revalida en background siempre, haya o no cache -- así la
        // primera visita a una pantalla también deja el cache listo
        // para la próxima, sin esperar a que el usuario vuelva a pasar.
        const revalidate = fetch(event.request).then((response) => {
          if (response.ok) cache.put(event.request, response.clone());
          return response;
        });
        // Cache disponible: instantáneo. Si no hay cache (primera vez
        // que se visita esta pantalla), no hay nada que servir todavía
        // -- se espera la red igual que hoy.
        return cached || revalidate;
      })
    )
  );
  return;
}
```

### Invalidación post-mutación

Mismo listener `fetch`, branch nuevo para métodos de escritura, colocado antes de cualquier otro branch (no compite con ellos, esos son todos GET-only):

```js
if (['POST', 'PATCH', 'PUT', 'DELETE'].includes(event.request.method) &&
    url.origin === self.location.origin) {
  event.respondWith(
    fetch(event.request).then((response) => {
      if (response.ok) {
        caches.delete(SWR_CACHE);
      }
      return response;
    })
  );
  return;
}
```

No se intercepta el resultado ni se altera el flujo — el submit sigue yendo 100% a red, se lee su respuesta solo para decidir si invalidar, y se devuelve intacta. Si el submit falla (red caída o error del servidor), no se invalida nada — el cache existente sigue siendo válido.

### Limpieza en `activate`

`SWR_CACHE` se agrega a la lista de nombres protegidos en el `activate` handler existente, junto a `CACHE_VERSION` y `RUNTIME_CACHE`, para que el ciclo de limpieza de caches obsoletos (ya implementado) no la borre por error, y para que un cambio de versión futura la trate igual que a las demás.

## Edge cases

- **Sin conexión y sin cache para esa pantalla** (primera visita, nunca estuvo cacheada): `fetch()` rechaza, no hay `.catch()` en el branch SWR — se propaga el error de red tal cual, mismo comportamiento que tendría hoy sin este cambio (no se agrega manejo nuevo porque el branch `navigate` ya resuelve el caso de "pantalla nunca visitada, sin red" con el offline.html; el caso Turbo sin red y sin cache es equivalente en severidad y no estaba cubierto antes tampoco).
- **Turbo Stream responses** (respuestas parciales a acciones dentro de una página, no full-page): mismo Accept header las incluye en el branch SWR, se cachean igual que una página completa — inofensivo, Turbo las aplica y descarta, nunca se vuelven a pedir como si fueran la página entera.
- **Cache SWR corrupto o con una versión de HTML vieja de un deploy anterior**: mismo mecanismo de invalidación por deploy que ya limpia `CACHE_VERSION`/`RUNTIME_CACHE` en `activate` cubre `SWR_CACHE` (ver arriba) — un deploy nuevo no arrastra cache stale de una versión de código distinta.
- **Mutación exitosa pero el usuario no vuelve a navegar** (cierra la app): sin impacto, el cache vacío simplemente se repuebla en la próxima sesión igual que si nunca hubiera tenido cache.

## Testing

Manual, sobre el APK real en el dispositivo (no hay suite automatizada de service worker en este proyecto):

1. Abrir Transacciones dos veces seguidas → segunda apertura debe pintar sin loader/delay visible.
2. Crear una transacción nueva → volver a Transacciones → debe aparecer sin re-tocar nada (confirma invalidación).
3. Modo avión, tras haber visitado Transacciones y Cuentas al menos una vez con red → ambas pantallas deben servir desde cache SWR, no caer al offline.html genérico.
4. Modo avión, en una pantalla nunca antes visitada → debe comportarse igual que hoy (sin regresión): fallback a offline.html si es cold-open, o error de red sin cache si es navegación Turbo interna (edge case documentado arriba, sin cambio de comportamiento respecto al estado actual).
