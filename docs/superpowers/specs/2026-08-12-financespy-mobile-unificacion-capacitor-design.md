---
title: "Unificación de iniciativas móviles FinancePY — Capacitor como base única"
created: 2026-08-12
status: approved
---

# Unificación de iniciativas móviles FinancePY — Capacitor como base única

## Contexto y objetivo

Se descubrieron 3 iniciativas móviles construidas sin coordinación entre sí:

1. **TWA/Bubblewrap** (`financespy` repo) — wrapper simple, sin offline, sin captura Wallet. APK generado, sideload.
2. **Capacitor offline-first** (`cd-co-erp` repo, rama `feature/android-offline-phase1`) — WebView en modo remoto sobre la app Rails real, con offline read+write ya implementado del lado web (IndexedDB + `/sync/transactions`). Ver `docs/superpowers/specs/2026-08-05-financespy-android-offline-design.md`. Fase 1 shippeada, sin mergear.
3. **React Native `financespy-app`** (`financespy` repo, rama `feature/financespy-mobile-app`) — app nativa separada para captura de notificaciones Wallet (compras) + login OAuth/Doorkeeper. Login recién resuelto (ver `wiki/meta/Sesión 2026-08-11-12 FinancePY RN app login OAuth resuelto.md` del vault) — causa raíz del bug fue un `--build` faltante en el deploy, no un defecto de código.

El usuario definió el requisito no negociable: **una sola app instalable**, no varias conviviendo — "el usuario final no va a querer instalar dos apps".

Diseñado siguiendo `superpowers:brainstorming`. Investigación de la arquitectura real de la rama Capacitor hecha vía clon read-only (`gh repo clone fabriziocorbeta/cd-co-erp --branch feature/android-offline-phase1`) y lectura directa de `docs/CAPACITOR.md` del repo, no memoria de la conversación previa.

## Alcance (confirmado con el usuario)

- Consolidar las 3 iniciativas en **una única app Capacitor**, manteniendo todo lo ya shippeado en la rama offline-first (`feature/android-offline-phase1`) como base.
- Portar la funcionalidad de captura de notificaciones Wallet del RN app (`financespy-app`) a esa misma base Capacitor, como plugin nativo.
- Retirar: TWA como distribución independiente, el RN app como app standalone instalable, el código OAuth/Doorkeeper mobile-específico (queda sin uso una vez que el login pasa a ser la cookie de sesión real, ya usada por Capacitor).

Fuera de alcance explícito (YAGNI):
- Reescribir el listener de Wallet desde cero — se porta el `WalletNotificationListenerService` (Kotlin) existente, cambiando solo el bridge de invocación (RN Native Modules → Capacitor Plugin API).
- Tocar el backend (`POST /webhooks/android_purchase`, token fijo) — sin cambios, ya en producción.
- Publicación en Play Store — sigue siendo sideload, sin cambios de distribución más allá de consolidar en un solo APK.
- Timeline/plan de decomisión formal de TWA y RN app como distribuciones — se listan como retiradas en este spec, pero el cuándo/cómo (¿se deja de generar el APK ya, o se sostiene hasta confirmar la app unificada en un dispositivo real?) es una decisión de ejecución para el plan de implementación, no de este documento de diseño.

## Arquitectura

- **Base**: Capacitor (ya construido, rama `feature/android-offline-phase1` en `cd-co-erp`) sigue siendo el shell — WebView en modo remoto (`server.url` → `https://finance.cd-co.com.py`) mostrando la app Rails real, con todo lo offline que ya tiene (IndexedDB + `/sync/transactions`, ver `app/javascript/services/offline_transactions_*.js`).
- **Agregado**: el listener de Wallet se porta como **plugin nativo de Capacitor** (Kotlin) — mismo `WalletNotificationListenerService` que ya existe en el RN app, conectado vía el bridge de plugins de Capacitor (`@CapacitorPlugin`) en vez del de React Native (`NativeModules`). Sigue posteando al mismo webhook — no cambia el backend para nada.
- **UI del permiso/debug**: en vez de pantallas React separadas (como en el RN app), se agrega una sección chica a la app Rails real (Settings → "Activar captura automática de Wallet") que llama al plugin vía JS bridge (`Capacitor.Plugins.WalletListener`) para pedir el permiso nativo. El plugin no necesita ninguna pantalla propia — todo sigue siendo la web real, consistente con cómo ya funciona Capacitor acá.
- **Se retira**: TWA (dominado por completo por esta app), el RN app como app standalone instalable, y el código OAuth/Doorkeeper mobile que se construyó en la sesión 2026-08-11/12 (queda sin uso — el login pasa a ser la cookie de sesión real del WebView aislado de Capacitor, ya validada y en producción para el resto de la app).

## Componentes (nivel técnico)

- **Plugin nativo Kotlin**: mismo `WalletNotificationListenerService` de RN app, portado a Capacitor Plugin API — clase `@CapacitorPlugin`, métodos `requestPermission()` / `isListenerEnabled()` expuestos a JS vía `this.notifyListeners(...)`.
- **Bridge JS**: `Capacitor.Plugins.WalletListener` reemplaza `NativeModules.WalletListener` de RN — mismo patrón call/callback, sintaxis distinta nomás.
- **Cola de reintentos**: portar `pendingQueue.ts` (RN) casi sin cambios — es lógica TS pura, sin dependencia de React Native. Se integra al JS ya existente de la app Rails (mismo bundle que maneja `offline_transactions_*.js` de la Fase 1 offline).
- **Webhook destino**: sin cambios — `POST /webhooks/android_purchase`, token fijo, ya en prod.

## Flujo de datos

Notificación Wallet → `WalletNotificationListenerService` (foreground service Android, sigue vivo con la app en background/killed) → parseo monto/comercio → plugin encola en `pendingQueue` (IndexedDB, mismo store offline de la Fase 1) → con red: POST inmediato a `/webhooks/android_purchase` → sin red: queda en cola → el mismo listener `online`/sync-on-reconnect que ya usa `offline_transactions_*.js` la despacha cuando vuelve la conexión.

## Manejo de errores / edge cases

- **Permiso de notificaciones denegado**: el plugin devuelve error tipado; la UI (Settings en la app Rails) muestra estado "no activado" con botón para reintentar la solicitud de permiso.
- **App en background/killed**: `WalletNotificationListenerService` es servicio Android persistente, no depende de que la WebView esté activa — igual que en el RN app, sin cambios de comportamiento.
- **Falla de red al postear**: entra a `pendingQueue`, mismo mecanismo de retry con backoff que ya tienen las transacciones offline (base 5s, tope 60s, según el patrón documentado en el spec de la Fase 1) — no se reinventa.
- **Duplicados** (mismo pago capturado dos veces): el backend ya dedupea por hash de notificación en el webhook existente — sin cambios necesarios acá.

## Testing

- Los 3 puntos "sin verificar todavía" de `docs/CAPACITOR.md` (arranque en frío sin conexión, persistencia de login entre reinicios, sync al reconectar) se verifican en dispositivo real como parte de cerrar esta migración — no estaban confirmados antes de este spec y ahora quedan bloqueando el cierre.
- Caso nuevo a sumar: notificación Wallet capturada con la app cerrada → abrir la app → confirmar que el pago aparece en la cola o ya sincronizado, sin duplicados.
- Sin tests unitarios nuevos más allá de portar los que ya existan para `pendingQueue.ts` — es lógica pura, no debería necesitar mocks nuevos al cambiar de runtime.

## Notas de implementación

- Partir de la rama `feature/android-offline-phase1` de `cd-co-erp` como base — no desde cero.
- El código OAuth/Doorkeeper mobile-específico de `financespy` (controlador, vista `new.html.erb`, headers no-store) queda sin caller una vez migrado esto — no se borra en este spec, se señala como candidato a retiro en el plan de implementación.
- Orden sugerido: (1) portar el plugin Kotlin + bridge, (2) portar `pendingQueue.ts` y engancharlo al store offline existente, (3) UI de Settings, (4) verificar los 3 puntos pendientes de `docs/CAPACITOR.md` en dispositivo real, (5) recién ahí decomisionar TWA y RN app como distribuciones.
