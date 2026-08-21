---
type: session
title: "Sesión 2026-08-11/12 FinancePY — RN app login OAuth resuelto, causa raíz --build"
created: 2026-08-11
updated: 2026-08-12
tags: [financespy, android, react-native, oauth, doorkeeper, docker, sesion]
status: resuelto
related:
  - "[[FinancePY — APK Android (TWA) con Bubblewrap]]"
  - "[[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]]"
  - "[[financespy]]"
---

# Sesión 2026-08-11/12 — FinancePY RN app: login OAuth resuelto, causa raíz fue `--build` faltante

## Resumen

El RN app `financespy-app` (captura de notificaciones Google Wallet en background) se probó en producción real por primera vez. El login OAuth (Doorkeeper, redirect a esquema custom `financespy://oauth/callback`) se quedaba colgado en la pantalla de autorización — reproducido de forma **idéntica** en desktop Safari y en el teléfono real, sin cambiar pese a 4 fixes de código reales y verificados en el repo. La causa real no era ninguno de esos fixes: era que el comando de deploy usado toda la sesión nunca reconstruía la imagen Docker, así que ningún fix llegó a ejecutarse nunca.

## Los 4 fixes de código (reales, correctos, pero irrelevantes hasta el fix de deploy)

1. **`DS::Button` con `href:` dentro de un `form_tag`** (`app/views/doorkeeper/authorizations/new.html.erb`) — Rails `button_to` genera su propio `<form>` anidado dentro del `form_tag` exterior, HTML inválido que dejaba a Turbo Drive interceptando el submit pese a `data-turbo="false"` en la form exterior. Fix: sacar `href:`, el componente ya soporta renderizar como `<button type="submit">` plano cuando no se le pasa href.
2. **Headers `Cache-Control: no-store, no-cache, private` + `Pragma: no-cache`** agregados explícitamente en `Doorkeeper::AuthorizationsController` — belt-and-suspenders contra cualquier cacheo de una página personalizada (CSRF token, sesión).
3. **`data-turbo="false"` directo en los botones** Authorize/Deny, no solo en la form.
4. **`data-turbo="false"` en el `<body>`** del layout compartido de Doorkeeper — máxima autoridad posible, cascada a todo enlace/form de la página.

Los 4 están commiteados y pusheados a `main` de `financespy` (commits `7451dc5`, `97cbd67`, `45fb334`, `c5f285b`).

## La causa real

`compose.local.yml` define `web: build: .`. El `Dockerfile` hace `COPY . .` y precompila assets en build-time — no hay volumen en vivo montando el código de la app. El comando de deploy repetido toda la sesión:

```bash
docker compose -f compose.local.yml --env-file .env.local up -d --force-recreate web
```

reinicia el contenedor con la **imagen ya cacheada**, sin reconstruirla. Cada `git pull` en la notebook actualizaba los archivos en disco, pero nunca llegaban a la imagen. El env var `PRODUCT_NAME=FinancePY` se veía correcto en el contenedor en vivo (`docker compose exec web env`) porque se inyecta en runtime vía `--env-file`, no forma parte de la imagen — esto generó una pista falsa real: "el env está bien pero el HTML sigue viejo", que llevó a descartar (correctamente) una hipótesis de config y perseguir (incorrectamente, por un buen rato) hipótesis de caché/infra.

Comando correcto:

```bash
docker compose -f compose.local.yml --env-file .env.local up -d --build web
```

Con este único cambio, el login funcionó en el primer intento real. No fue posible aislar cuál de los 4 fixes de código era estrictamente necesario — se aplicaron los 4 antes de descubrir el problema de deploy. La sospecha razonable es que el fix #1 (formulario anidado) era el único realmente necesario, y los otros 3 son defensa en profundidad no confirmada individualmente.

## Descartes reales hechos en el camino, verificados uno por uno

Antes de encontrar la causa real se investigaron y **descartaron con evidencia directa** (no supuestos) varias hipótesis de infraestructura:

- **Cache de Cloudflare**: el usuario purgó todo desde el dashboard, sin efecto observable. Se confirmó además **0 Cache Rules y 0 Cache Response Rules** configuradas — no había ninguna regla cacheando la página.
- **Service Worker / cache del navegador**: desregistrado y `caches.delete()` corrido manualmente en la consola de Safari, con reload real posterior — sin efecto.
- **Segunda VM sirviendo tráfico en paralelo** (la VM GCP vieja, `alejandro-vm`): descartado con `gcloud` corrido directamente — cero instancias corriendo en los 8 proyectos GCP accesibles de la cuenta, Compute Engine API ni siquiera habilitada en `cd-co-finanzas`. La única VM que existe en toda la cuenta está `TERMINATED`.
- **Contenedor `web` duplicado/huérfano**: descartado con `docker ps -a --filter name=web`, un solo contenedor.
- **Test que parecía decisivo pero era un falso positivo**: parar el contenedor `web` (`docker compose stop web`) y la página "seguía funcionando" — parecía probar que había otro backend. Explicación real: el propio Service Worker de la PWA (`app/views/pwa/service-worker.js`) tiene una función `isOriginUnreachable()` que detecta 502 (Caddy sin upstream) y sirve la última copia cacheada por diseño — un comportamiento offline-friendly intencional que, en este contexto de debugging, casi lleva a una conclusión completamente equivocada.

## Lección para toda sesión futura que toque `compose.local.yml`

**SIEMPRE usar `--build` al deployar cualquier cambio de código (Ruby/JS/ERB/CSS).** `--force-recreate` solo alcanza para cambios de configuración/env vars — no reconstruye la imagen. Este mismo patrón de Dockerfile (`COPY . .` en build-time, sin volumen de código en vivo) ya causó un incidente similar el 2026-08-04: un fix de OOM (`5656158`, límites de memoria + `WEB_CONCURRENCY=1`) nunca llegó a desplegarse porque `compose.local.yml` no lo tenía agregado — es la segunda vez que un deploy "exitoso" en apariencia no trae el código real.

## Descubrimiento colateral: 3 iniciativas móviles sin decisión tomada (no 2)

Al confirmar el login funcionando, el usuario preguntó si el RN app reemplazaba el uso diario de la web/PWA — no es así, su propósito es único y acotado: captura de notificaciones Wallet en background + pantalla mínima de "transacciones recientes" para verificación. Esto expuso una confusión real: hay **tres** iniciativas móviles construidas en sesiones distintas, sin que ninguna decidiera explícitamente contra las otras dos:

| # | Iniciativa | Propósito | Repo / rama | Estado |
|---|---|---|---|---|
| A | TWA / Bubblewrap | Wrapper simple de la PWA, sin offline, sin captura Wallet | `financespy`, generado directo en la notebook | APK generado, sideload funcional |
| B | Capacitor offline-first | Lectura/escritura de transacciones sin conexión, sync RxDB | `cd-co-erp`, rama `feature/android-offline-phase1` | Fase 1 shippeada, **sin mergear** |
| C | React Native `financespy-app` | Captura Wallet + OAuth (esta sesión) | `financespy`, rama `feature/financespy-mobile-app` | Login funcionando, **sin mergear** |

Ninguna sabía de las otras dos al momento de construirse. La decisión de cuál(es) seguir, y cómo conviven, quedó como brainstorming iniciado (skill `superpowers:brainstorming`) al cierre de esta sesión — sin resolver.

## Ver también

- [[FinancePY — APK Android (TWA) con Bubblewrap]] — iniciativa A
- [[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]] — iniciativa B, incluye la contradicción ya documentada entre A y B (esta sesión suma la C)
- [[financespy]] — nota principal del proyecto
