# FinancePY app nativa iOS — Wave 1a (fundación: auth + SwiftData sync engine + Dashboard + Transacciones)

## Contexto y objetivo

Continuación directa de la decisión de app nativa Android (`docs/superpowers/specs/2026-08-19-financespy-native-android-1a-design.md`). Tras cerrar wave 1b de Android y portar el design system real (Sure) a Compose, el usuario decidió explícitamente construir también una app nativa **Swift/SwiftUI separada** para iOS — no Compose Multiplatform (que hubiera reusado el Kotlin de Android sin escribir Swift), sino una segunda implementación nativa independiente, mismo criterio de costo ya aceptado a ojos abiertos para Android nativo vs WebView.

Mismo patrón de secuenciación que Android: **1a (este spec) es la fundación de mayor riesgo arquitectónico** — auth + sync engine local + Dashboard + Transacciones. Wave siguiente (equivalente a "1c" de Android) trae Presupuestos/Metas/Cuentas a Cobrar — a diferencia de Android, esa wave ya no está bloqueada por trabajo de backend: el CRUD completo de Budgets/Goals/Receivables se shippeó hoy mismo (PRs #75/#76/#77, mergeados y deployados en `main`), disponible para ambas plataformas desde ya.

## Alcance (confirmado con el usuario)

- **Stack**: SwiftUI (UI) + `URLSession` async/await (networking, sin librerías de terceros) + `SwiftData` (persistencia local, requiere **iOS 17+** como mínimo soportado — decisión explícita del usuario) + `ASWebAuthenticationSession` (OAuth PKCE nativo de Apple, sin librería). Cero dependencias externas — mismo espíritu minimalista que Android, donde Ktor/Room/Koin se justificaban por ser multiplatform (requisito que no aplica acá).
- **Auth**: OAuth2 PKCE contra la misma app Doorkeeper ya existente `"FinancePY Mobile"` (`client_id = Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM`, `redirect_uri = financespy://oauth/callback`, `scope = read_write`) — mismo backend, cero trabajo de servidor, cero app Doorkeeper nueva.
- **APIs consumidas tal cual**: `accounts`, `balance_sheet`, `transactions`, `auth`. Mismos endpoints que consume Android 1a.
- **Sync — MVP sin delta, igual que Android**: full refetch en cada sync (sin `updated_since`, sin tombstones — mismo hallazgo de Android: `Entry`/`Transaction`/`Account` son hard-delete, sin `deleted_at`). Ventana de transacciones: 90 días. Cuentas y balance sheet: completos, sin ventana. Trigger: foreground + pull-to-refresh manual. Sin background sync (`BGTaskScheduler`) en 1a.
- **Pantallas 1a**: Login (OAuth PKCE) → Dashboard (patrimonio neto vía `balance_sheet`, lista de cuentas, transacciones recientes) → Transacciones (lista paginada, filtros básicos: cuenta, categoría, rango de fecha).
- **Persistencia SwiftData**: mirror del split `entries`/`transactions` del server (mismo criterio que Room en Android — `Entry` es la tabla base compartida con `account_id`/`date`/`name`/`amount`/`currency`/`parentEntryId`/`transferId`, `Transaction` es `@Model` separado con `categoryId`/`merchantId`/`kind`, vinculado 1:1 vía `entryableId`). No aplanar en una sola entidad.
- **Sin design system todavía**: SwiftUI con estilos default del sistema — se porta el design system real (Sure) en su propia wave posterior, mismo orden que se hizo para Android (donde el intento de construir sin diseño llevó a bloquear 1c/1d hasta portarlo — acá se documenta la lección desde el inicio en vez de descubrirla de nuevo).

Fuera de alcance explícito de esta wave (YAGNI, no del proyecto completo):

- Presupuestos, Metas, Cuentas a Cobrar — wave siguiente. El API ya existe (CRUD completo, PRs #75-77), así que esta wave debería ser más liviana que su equivalente en Android.
- Design system Sure portado a SwiftUI — wave posterior a esta, antes de escribir más pantallas (mismo aprendizaje que Android).
- Wallet-capture — no aplica a iOS (`UNNotificationServiceExtension` no puede leer notificaciones de otras apps, a diferencia de Android `NotificationListenerService`; iOS no tiene equivalente). Queda fuera del alcance de todo el proyecto iOS, no solo de esta wave.
- Delta-sync real, Dashboard completo (sankey/donut/income_statement/investment_statement) — mismos gaps de API que en Android, sin resolver todavía en ninguna plataforma.
- Publicación en App Store — build de desarrollo, instalado vía Xcode/TestFlight interno para pruebas, no distribución pública en 1a.

## Arquitectura

Nuevo directorio `native/financespy-ios/` en el mismo repo (`fabriziocorbeta/cd-co-erp`), junto a `native/financespy-kmp/` (Android) — no reemplaza ni depende del código Android, proyectos Xcode y Gradle completamente independientes que comparten solo el backend Rails.

- `FinancePYApp.swift` — entry point (`@main`), maneja el estado `isLoggedIn` y decide entre `LoginView`/contenido autenticado, mismo patrón que `MainActivity.kt`.
- `Auth/AuthRepository.swift` — construye la URL de autorización PKCE, intercambia el código por tokens, expone `isLoggedIn()`.
- `Auth/KeychainTokenStorage.swift` — tokens en **Keychain** (no `UserDefaults`, que no está cifrado) — mismo criterio de seguridad que `AndroidTokenStorage` (EncryptedSharedPreferences) en Android.
- `Network/ApiClient.swift` — configuración base de `URLSession` (base URL `https://finance.cd-co.com.py`, headers, decodificador JSON con `snake_case` → `camelCase` de Swift).
- `Network/FinancePyApi.swift` — métodos tipados por endpoint (`fetchAllAccounts()`, `fetchBalanceSheet()`, `fetchRecentTransactions(startDate:)`), estructuras `Codable` para cada DTO.
- `Persistence/Account.swift`, `Persistence/Entry.swift`, `Persistence/Transaction.swift` — `@Model` de SwiftData, mirror del split server-side descrito arriba.
- `Sync/SyncEngine.swift` — `syncAll()` que llama `syncAccounts()` → `syncTransactions()` → mismo orden secuencial que `SyncEngine.kt`, upsert + `deleteAllExcept`/`deleteStaleWithinWindow` (SwiftData `ModelContext` en vez de Room DAO).
- `Screens/LoginView.swift`, `Screens/DashboardView.swift`, `Screens/TransactionsView.swift` — SwiftUI, `@Query` de SwiftData para leer datos locales reactivamente (equivalente a los `Flow`/`StateFlow` de Android), `@Observable` view models.

## Manejo de errores

- Token expirado/revocado: forzar re-login completo vía `ASWebAuthenticationSession`, sin refresh silencioso indefinido — mismo criterio que Android.
- Falla de red durante full refetch: mantener los datos locales de SwiftData (última copia buena), mostrar "última sync hace Xm" — nunca vaciar la UI ante un fetch fallido.
- Sin escritura nativa en 1a (Login/Dashboard/Transacciones son de solo lectura desde el cliente) — no hay superficie de conflicto que resolver todavía; se decide estrategia cuando la wave de Presupuestos/Metas/Cuentas a Cobrar agregue creación/edición real.

## Testing

- Login PKCE completo en Simulador/dispositivo real: autorizar, volver a la app vía `financespy://oauth/callback`, confirmar tokens en Keychain y sesión persistente entre relanzamientos.
- Sync manual (pull-to-refresh) y automático (foreground): confirmar que SwiftData se actualiza sin duplicados tras refetch repetido.
- Modo avión: abrir la app sin red tras haber sincronizado antes, confirmar que Dashboard/Transacciones muestran la última copia local, no una pantalla vacía o un crash.
- Verificación real: Claude compila/corre en el Simulador de iOS de esta Mac (Xcode) — el pipeline remoto por SSH (notebook Windows/WSL2) no puede compilar Kotlin/Native ni proyectos Xcode, así que a diferencia de Android este build no pasa por el notebook.

## División de trabajo

Mismo patrón que el resto del proyecto: Jules escribe el código completo (estructura del proyecto Xcode, todos los archivos Swift listados arriba) vía prompt detallado. Diferencia real con los PRs de Rails/Kotlin: **el sandbox de Jules casi seguro no tiene Xcode/toolchain de Apple** (sandbox Linux) — no va a poder compilar ni correr el proyecto para confirmarlo, a diferencia de Kotlin (que sí pudo confirmar con Gradle) o incluso Rails (que al menos podía intentar `bin/rails test`). El prompt debe pedirle explícitamente que lo diga en la descripción del PR en vez de asumir que compila. Claude clona el resultado a esta Mac, abre en Xcode, compila y verifica en el Simulador antes de dar la wave por cerrada — el paso de verificación real recae 100% en Claude, no en Jules, desde el día 1 de esta wave (más estricto que Android, donde Jules sí pudo autoconfirmar compilación).

## Riesgos conocidos

- Es la primera vez que se compila código Swift/Xcode en este proyecto — puede haber fricción de setup (versión de Xcode, signing/provisioning para correr en Simulador sin cuenta de developer paga, que alcanza para Simulador pero no para dispositivo físico sin cuenta Apple Developer).
- Jules nunca escribió Swift en este proyecto — mayor probabilidad de errores de compilación reales en el primer intento comparado con Kotlin/Ruby, donde ya hay track record. Se espera necesitar más de una ronda de fixes antes de un build limpio.
