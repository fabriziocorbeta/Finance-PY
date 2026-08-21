---
title: "PWA Offline-First — FinancePY"
created: 2026-07-23
status: approved
---

# PWA Offline-First — FinancePY

## Contexto y objetivo

El usuario quiere que FinancePY se sienta como una app nativa en el celular, con capacidad real offline. La motivación no es la latencia geográfica (eso se resuelve aparte migrando el hosting a una PC local en Paraguay) — es que la app debe funcionar sin señal: ver lo ya visitado, y poder crear ventas incluso sin conexión.

Estado actual: existe una base PWA mínima (`app/views/pwa/service-worker.js`, registrado en `app/javascript/application.js`) que solo cachea una página estática `offline.html` cuando falla la red. No hay app shell cacheado, no hay IndexedDB, no hay cola de sincronización.

## Alcance (confirmado con el usuario)

- **Lectura offline:** cualquier página ya visitada antes debe verse sin conexión — todos los módulos (finanzas personales + ERP), no un subset.
- **Escritura offline:** limitada a **crear Ventas** — el caso de uso crítico de negocio. Otros módulos (transacciones, productos, pedidos, flota) quedan de solo lectura offline por ahora.
- **Dispositivo:** un solo usuario, un solo dispositivo a la vez — sin necesidad de resolver conflictos de sincronización entre múltiples dispositivos simultáneos.

Fuera de alcance explícito (YAGNI, no construir ahora):
- Escritura offline en módulos que no sean Ventas.
- Manejo de conflictos multi-dispositivo (nadie más usa la app offline en simultáneo hoy).
- Capa de datos cliente genérica (RxDB/PouchDB) — se evaluó como Approach C y se descartó por sobre-ingeniería para el scope actual.

## Arquitectura

Se extiende el service worker existente, no se reemplaza. Dos capas nuevas encima de lo que ya hay:

1. **Cache de lectura** (runtime caching de páginas/assets visitados)
2. **Cola de escritura** (IndexedDB, solo para creación de Ventas)

### Lectura offline

- El service worker intercepta `fetch` de navegaciones (GET de páginas) y assets estáticos.
- **Estrategia: network-first con fallback a cache** para navegaciones — intenta la versión viva primero (los datos financieros cambian, la frescura importa más que la velocidad instantánea de un cache-first). Si falla la red, sirve la última versión cacheada de esa página.
- Assets estáticos (JS/CSS/imágenes): cache-first — ya vienen versionados por fingerprint de Rails (Propshaft), seguro cachearlos agresivamente.
- Sin lista de pre-cache explícita: lo que el usuario visita se cachea como efecto secundario natural de la estrategia network-first (se guarda la respuesta exitosa en cache al mismo tiempo que se sirve).
- Se mantiene y reutiliza el patrón `CACHE_VERSION` ya existente para invalidación en despliegues nuevos.

### Escritura offline (solo Ventas)

- Nuevo controller Stimulus intercepta el submit del formulario en `sales/new`.
- Flujo:
  1. Intenta el submit normal (`fetch` al endpoint real).
  2. Si falla (sin conexión, o `navigator.onLine === false`), serializa el form y lo guarda en un object store de IndexedDB (`pending_sales`).
  3. Registra un tag de Background Sync (`sale-sync`) donde el navegador lo soporte (Chrome/Android). En iOS Safari (sin Background Sync API), fallback a reintento manual disparado por el evento `online` y al volver la app a primer plano (`visibilitychange`).
  4. Al sincronizar: el service worker lee `pending_sales`, hace `POST` a `SalesController#create` (requiere soporte JSON de respuesta — ver más abajo), borra el registro de IndexedDB si la respuesta es exitosa.
- **`sale_number` nunca se genera en el cliente.** Confirmado en `app/models/sale.rb`: se asigna server-side en `assign_sale_number` (`family.sales.maximum(:sale_number).to_i + 1`) recién cuando el `POST` real se procesa. Cero riesgo de colisión por diseño, no hay que inventar UUIDs temporales para esto.
- UI: sección "Ventas pendientes de sincronizar" en `/sales`, renderizada client-side leyendo IndexedDB, visualmente distinta de la tabla real server-rendered, con estado claro (pendiente / sincronizando / error).

### Cambio de backend necesario

`SalesController#create` hoy solo responde HTML (redirect en éxito, re-render en error). Se agrega `respond_to` con formato JSON para que el service worker pueda parsear éxito/error de forma confiable al reproducir la cola (parsear un redirect HTML desde un service worker es frágil).

## Manejo de errores

- Con un solo dispositivo, no hay race de stock entre dispositivos offline simultáneos.
- El stock **no se valida** al crear el draft offline (mismo comportamiento que la creación online hoy — el chequeo de stock ocurre recién en `complete!`). Completar la venta sigue siendo un paso manual posterior, igual que en el flujo online actual.
- Si el `POST` de sincronización falla con un error real de servidor (ej. producto borrado mientras estaba offline), el ítem se marca **"necesita revisión"** en la UI en vez de perderse silenciosamente o reintentarse indefinidamente.
- Reintento de red con backoff exponencial (base 5s, doblando hasta un tope de 60s entre intentos), máximo 5 intentos automáticos (evita loop infinito si la red sigue caída); después del tope, queda disponible para reintento manual explícito desde la UI de pendientes.

## Testing

- Verificación manual (no hay entorno de test local con Ruby funcional, ver limitación conocida del proyecto): modo avión en Chrome DevTools/celular real → crear venta → reconectar → confirmar que sincroniza con un `sale_number` correcto y sin duplicados.
- Verificar que páginas visitadas antes (varios módulos) cargan offline tras haberlas visitado una vez online.
- Verificar el fallback de iOS Safari (sin Background Sync) — reintento manual al reabrir/foreground.
- Request spec nuevo para el soporte JSON de `SalesController#create` (sí es viable correr specs unitarios acotados, la limitación conocida es sobre el test suite completo con fixtures, no bloquea specs nuevos acotados si se verifican con cuidado).

## Notas de implementación

- No tocar la arquitectura Rails/Turbo/Hotwire existente — todo esto se agrega como una capa encima, no reemplaza el modelo de renderizado server-side.
- Reusar convenciones ya establecidas: `row_click_controller.js` como referencia de patrón Stimulus simple y aislado para el nuevo controller de interceptar el submit.
- Si el offline-write crece a más módulos en el futuro, ahí sí evaluar migrar a una capa tipo Approach C (RxDB/PouchDB) — no antes.
