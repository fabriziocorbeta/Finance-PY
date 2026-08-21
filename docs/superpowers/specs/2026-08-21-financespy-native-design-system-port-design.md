# FinancePY native Android — puerto del design system real (Sure) a Compose

## Contexto

La app nativa (`native/financespy-kmp/`, KMP + Compose Multiplatform) usa `MaterialTheme` de Compose sin configurar — texto plano, morado default de Material3. FinancePY (la app Rails real) tiene un design system propio y maduro (`app/assets/tailwind/sure-design-system/{base.css,components.css,_generated.css,prose.css}`), con tokens semánticos de color con variantes claro/oscuro, tipografía Geist, y componentes con sus propios variantes (botones, inputs, cards).

El usuario notó la discrepancia al ver la primera pantalla nativa funcional (`RuleFormScreen`) y decidió explícitamente: portar el design system real bloquea wave 1c (CRUD completo Budgets/Goals/Receivables) y wave 1d (wallet-capture) — no seguir construyendo pantallas sin estilo.

## Alcance

Colores + tipografía + componentes custom (no solo colores). Justificación: Sure tiene 5 variantes de botón (primary/secondary/secondary-strong/ghost/destructive) que no encajan bien en los ~3-4 estilos que trae `Button` de Material3 out-of-the-box — mapear directamente a `ColorScheme` hubiera perdido esa distinción.

Tokens semánticos, no la escala completa de color (~60 tokens gray/red/green/etc). Solo lo que las pantallas actuales necesitan: fondo (surface/container/container-hover), texto (primary/secondary/subdued), borde (primary/secondary), estados (success/warning/destructive), y los 5 fondos de botón. Extender el set de tokens es trivial si una pantalla futura necesita algo más — no vale la pena portar hoy código que nadie usa.

## Arquitectura

Nuevo paquete `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/theme/`:

- **`Color.kt`** — objeto `FinancePyColors` con funciones `@Composable` que devuelven `Color` leyendo `isSystemInDarkTheme()`, uno por token semántico (`surface()`, `container()`, `containerHover()`, `textPrimary()`, `textSecondary()`, `textSubdued()`, `borderPrimary()`, `borderSecondary()`, `success()`, `warning()`, `destructive()`, y los 5 fondos de botón). Valores hex tomados 1:1 de `_generated.css` (líneas 10-27 para la escala gray, 197-560 para los tokens semánticos claro/oscuro).
- **`Type.kt`** — `Typography` de Material3 construida sobre `FontFamily(Font(...))` con los 4 pesos Geist (Regular/Medium/SemiBold/Bold). Mono (Geist Mono) queda afuera, no lo usa ninguna pantalla nativa hoy.
- **`Theme.kt`** — `FinancePyTheme { content -> ... }`, un `CompositionLocal` (`LocalFinancePyColors`) que expone `FinancePyColors` a los composables hijos, envolviendo `MaterialTheme` (se sigue usando Material3 como base para `Text`/`Surface`/etc, pero con la tipografía Geist).
- **`components/AppButton.kt`** — `AppButton(text, onClick, variant: ButtonVariant = Primary, enabled = true)`, enum `ButtonVariant { Primary, Secondary, SecondaryStrong, Ghost, Destructive }`, forma `RoundedCornerShape(8.dp)` (matchea `rounded-lg` del CSS).
- **`components/AppTextField.kt`** — replica `.form-field`: borde sutil (`borderSecondary`), radio `rounded-md` (6.dp), anillo de foco.
- **`components/AppCard.kt`** — fondo `container`, borde `borderSecondary`, usado en listas.

### Fuente Geist

Solo existe como `.woff2` en el repo (formato web, `app/assets/fonts/geist/`). Se bajan los 4 `.ttf` reales (Regular/Medium/SemiBold/Bold) de `github.com/vercel/geist-font` (open source) a `commonMain/composeResources/font/`.

### Migración de pantallas existentes

`App.kt` cambia `MaterialTheme { ... }` por `FinancePyTheme { ... }`. Pantallas que hoy usan `Button`/`TextField` genéricos de Material3 pasan a `AppButton`/`AppTextField`: `LoginScreen`, `DashboardScreen`, `RulesListScreen`, `RuleDetailScreen`, `RuleFormScreen`, `TransactionsScreen`, `AccountDetailScreen`.

## Testing / verificación

No hay unit tests posibles para UI Compose en este setup (mismo problema documentado de siempre — falta de entorno de test local). Verificación real: build + instalación en dispositivo físico, comparación visual pantalla por pantalla contra el diseño real de la web (misma paleta, mismo peso tipográfico, mismos radios de borde). La corre Claude directamente, no Jules — Jules no tiene acceso a un dispositivo Android.

## División de trabajo

Todo el código (tokens, fuente, componentes, wiring de `App.kt`, migración de las 7 pantallas) se delega a Jules vía prompts detallados — el patrón ya usado para el CRUD de Budgets/Goals/Receivables. Claude solo hace: review de cada PR antes de merge (mismo criterio que #74/#75/#76/#77: buscar bugs reales, no solo estilo), build + instalación + verificación visual en dispositivo físico real, y deploy/documentación.

## Riesgos conocidos

- Jules no puede compilar/correr la app KMP en su sandbox (mismo problema que con Rails: entorno restringido) — no va a poder confirmar visualmente que el resultado se ve bien, solo que compila (si es que su sandbox tiene Android SDK/Gradle configurado — a confirmar en el primer prompt). La verificación visual real recae 100% en Claude con el dispositivo físico.
- Los 5 variantes de botón son una interpretación de los 5 selectores `button-bg-*` del CSS (`_generated.css:404-464`) — no hay un enum explícito en el código Rails que los agrupe así, es una inferencia razonable pero no una copia literal de una estructura de datos existente.
