---
title: "App Android nativa FinancePY — Rediseño de Presupuestos (dashboard mensual real)"
created: 2026-09-08
status: approved
---

# App Android nativa FinancePY — Rediseño de Presupuestos (dashboard mensual real)

## Contexto y objetivo

`BudgetDashboardScreen` (wave 1c, PR #111) se construyó como un CRUD simple, mismo patrón que Reglas — pero Presupuestos en la web real no es un CRUD, es un dashboard mensual (donut, tabs Presupuestado/Real, categorías con estado, editor de asignación aparte). El equipo ya marcó esto explícitamente como un error de forma de producto (sesión 2026-08-24-25) y decidió que hacía falta un rediseño desde cero, bloqueado en ese momento por el port del design system.

El design system YA está portado y aplicado en 12 de las 13 pantallas nativas (`FinancePyTheme`/`AppButton`/`AppTextField`/`AppCard`, commits `96a8b4b`/`80677c3`) — el bloqueo original ya no existe. `BudgetDashboardScreen` es la ÚNICA pantalla que quedó sin re-skinear, justamente porque de todos modos había que rehacerla entera.

Investigando esta wave para escribir el spec se encontraron dos problemas reales de backend, ya arreglados hoy mismo (fuera de `native/`, en el repo Rails real):

- **Bug crítico de RLS (PR #234, mergeado):** ningún request de la API v1 (OAuth ni API key) activaba el contexto de Row-Level-Security de Postgres — la API entera devolvía `HTTP 200` con colecciones vacías en vez de datos reales, para CUALQUIER endpoint. Esto probablemente explica por qué las pantallas nativas existentes se vieron "más vacías/limitadas" de lo esperado en verificaciones anteriores en dispositivo.
- **`BudgetDto` ya anticipaba** (comentario propio en el código: "Additional fields expected when API is upgraded to full dashboard parity") los campos `actual_spending`/`available_to_spend`/`categories`/`donut_segments` — pero el serializer Rails nunca los llenaba, solo extraía columnas crudas. Ya extendido (PR #235) con el dashboard completo: totales de gasto/asignación/ingreso, segmentos del donut, presupuesto fuente para "copiar del mes anterior", y desglose completo por categoría (padre y subcategoría) con badges de estado, barra de progreso, promedio/mediana, gasto diario sugerido.
- **Faltaba el endpoint para editar la asignación de una categoría individual** — no existía ninguna ruta de API para esto. Agregado (`PATCH /api/v1/budgets/:budget_id/budget_categories/:id`, mismo PR #235), reusa `BudgetCategory#update_budgeted_spending!` (el mismo método que ya usa la web, maneja lock + herencia de subcategoría + recompute en una transacción).

De paso se encontraron y arreglaron 3 bugs reales de nil-guard en `Budget` (`percent_of_budget_spent`, `actual_income_percent`, `remaining_expected_income`, `surplus_percent`) que crasheaban o devolvían `Infinity` (no serializable a JSON) para un presupuesto sin inicializar — un estado completamente normal (ej. el mes actual antes de configurarlo la primera vez).

**Además, en la misma investigación se encontró y arregló toda la traducción faltante de esta pantalla en la web** (PR #233) — el drawer de detalle, el editor de asignación y los resúmenes estaban casi 100% en inglés hardcodeado. El spec de abajo usa los textos en español YA correctos, no hace falta retraducir nada del lado nativo.

## Alcance

Replicar exactamente la pantalla web real (`app/views/budgets/show.html.erb` + partials, ya releídos y confirmados durante esta investigación), con los componentes del design system ya portado, ADAPTANDO A TODOS LOS TAMAÑOS DE PANTALLA (pedido explícito del usuario — ver sección de responsividad, es territorio nuevo, ninguna de las 13 pantallas existentes lo hace hoy).

Piezas de la pantalla (todas dentro de un solo `BudgetDashboardScreen` rediseñado, más 2 pantallas nuevas):

1. **Header de navegación mensual**: chevron-izquierda/derecha (deshabilitados en los límites de rango válido, mismo criterio que `Budget.budget_date_valid?`), nombre del mes/año con dropdown de selección directa (picker), link "Hoy" que salta al mes actual.
2. **Sección superior, dos bloques** (ver responsividad — apilados en compacto, lado a lado en ancho medio+):
   - **Donut**: si `!initialized && source_budget != null` → prompt "copiar del mes anterior" (botón copiar + botón "empezar desde cero"); si `initialized && available_to_allocate < 0` → warning de sobre-asignación con botón "Corregir asignaciones"; si no → donut real con "Gastado" + monto + "de {budgeted}" (o "Nuevo presupuesto" si nunca se inicializó), tap en un segmento muestra el desglose de esa categoría (mismo patrón que la web: swap de contenido central).
   - **Tabs Presupuestado/Real**: dos pestañas, cada una mostrando Ingresos/Gastos (tab Real) o Ingreso esperado/Presupuestado (tab Presupuestado) con barra de progreso de dos colores y el texto "ganado"/"de más"/"disponible"/"gastado" (ver claves exactas en Notas de i18n).
3. **Lista de categorías, ancho completo**: header con título "Categorías" + contador, botón "Editar" (abre el editor de asignación), tabs de filtro Todas/Sobre presupuesto/En camino (solo si hay al menos una categoría sobre presupuesto — mismo criterio que `budget_has_over_budget?`). Cada fila: ícono+color de categoría, nombre, badge de estado (Sobre presupuesto/rojo, Alerta/amarillo, En camino/verde — mismos 3 estados que `reports.budget_performance.status.*`), barra de progreso, gastado/presupuestado/disponible o "de más", gasto diario sugerido si aplica. Subcategorías con indent + ícono "esquina-flecha-abajo-derecha", mismo agrupamiento que `BudgetCategory::Group.for` (agrupar por `category_parent_id`, no hay FK directa `budget_category_id` en el padre — se agrupa por la categoría subyacente).
4. **Detalle de categoría** (pantalla o bottom sheet nuevo, se abre al tocar una fila): "Categoría" + nombre, "Resumen" (gasto del mes, "Estado" con ícono+monto+"de más"/"disponible", "Presupuestado", "Gasto mensual promedio", "Gasto mensual mediano"), "Transacciones recientes" (últimas 3, con link "Ver todas las transacciones de la categoría" que navega a `TransactionsScreen` con filtro de categoría+rango de fechas ya aplicado — reusa `Api::V1::TransactionsController` existente, `category_id`+`start_date`+`end_date`, sin backend nuevo).
5. **Editor de asignación** (pantalla nueva, navegación separada desde el botón "Editar"): título "Editá los presupuestos por categoría" + descripción, barra de progreso de asignación total ("X% asignado" / "> 100% asignado" / "Superaste el presupuesto por X"), lista de categorías padre+subcategoría con input de monto inline (placeholder "Compartido" + tooltip "Dejá vacío para compartir el presupuesto de la categoría principal" para subcategorías sin monto propio), botón "Confirmar" (deshabilitado si `allocations_valid` es falso).

## Arquitectura nativa (KMP)

Mismo patrón ya probado en 1a/1b/1c — nada nuevo a nivel de stack de red/Room, solo el modelo de datos y las pantallas.

- **`BudgetDto`** (extender, `shared/src/commonMain/.../api/dto/BudgetDto.kt`) — agregar TODOS los campos nuevos que el jbuilder ya expone (nombres calcados 1:1, ver PR #235): `name`, `param`, `initialized: Boolean`, `current: Boolean`, `previous_budget_param`/`next_budget_param: String?`, `allocations_valid: Boolean`, `*_cents: Long?` junto a cada monto (usar los `_cents` para aritmética exacta, los campos sin sufijo son `Double` de conveniencia para mostrar), `allocated_percent`/`percent_of_budget_spent`/`actual_income_percent`/`surplus_percent: Double`, `donut_segments: List<BudgetDonutSegmentDto>?` (ya existe el DTO), `source_budget: BudgetSourceDto?` (nuevo, `{id, name}`).
- **`BudgetCategoryDto`** (extender) — agregar `budget_id`, `category_icon`, `category_parent_id: String?`, `subcategory: Boolean`, `inherits_parent_budget: Boolean`, los `_cents` de cada monto, `bar_width_percent`, `over_budget`/`near_limit`/`budgeted: Boolean`, `suggested_daily_spending: SuggestedDailyDto?` (nuevo, `{amount, amount_cents, days_remaining}`).
- **Mutación de asignación**: `PATCH /api/v1/budgets/{budgetId}/budget_categories/{id}` con body `{budget_category: {budgeted_spending: <number>}}`, devuelve el `BudgetCategoryDto` actualizado — va directo a la API (no pasa por Room primero, mismo patrón ya usado para mutaciones de Reglas en 1b), tras éxito refrescar solo ese `BudgetDto` en memoria (no hace falta re-sincronizar todo).
- **Room**: el dashboard de presupuesto puede seguir sin cachear en Room (igual que hoy) — es un dato que cambia con el período visible, no un catálogo; se pide on-demand al navegar de mes. Si en el futuro se quiere soporte offline, es una wave aparte.
- **Navegación**: 2 destinos nuevos en el `NavHost` ya existente — detalle de categoría (o `ModalBottomSheet` si se prefiere evitar una ruta completa) y editor de asignación. El editor necesita poder volver al dashboard y refrescar (mismo patrón que `RuleFormScreen` → `RulesListScreen`).

### Responsividad (territorio nuevo — ninguna pantalla existente lo hace hoy)

La web usa `grid-cols-1 md:grid-cols-2` (breakpoint Tailwind `md` = 768px) para el bloque donut+tabs — apilado en angosto, lado a lado en ancho medio+. Compose Multiplatform no tiene un `WindowSizeClass` verdaderamente portable entre Android/iOS/Desktop en el mismo módulo `commonMain` sin dependencias extra — usar `BoxWithConstraints` con un único breakpoint (recomendado: **640.dp**, coincide con el límite compact/medium de Material) para decidir `Row` vs `Column` en ese bloque. La lista de categorías y el resto de la pantalla van SIEMPRE a ancho completo (no necesitan el breakpoint). Confirmar que `BoxWithConstraints` compila igual en los targets configurados del proyecto (Android + los que existan en `commonMain`) antes de dar por cerrada esta pieza — riesgo conocido, no asumido como trivial.

## Manejo de errores

- Mismo patrón ya validado en 1a-1c: mostrar el último estado bueno conocido ante un fetch fallido, nunca vaciar la pantalla.
- Editor de asignación: validación mínima client-side (monto no negativo) antes de mandar, mostrar el mensaje real de error del server si la validación server-side falla (mismo criterio que Reglas en 1b).
- Un presupuesto sin inicializar (`initialized: false`) es un estado NORMAL, no un error — el dashboard debe manejarlo mostrando el prompt de copiar-o-empezar-de-cero, no un estado de carga/error.

## Testing

- Build real + instalación en dispositivo físico real antes de cerrar — mismo criterio que todas las waves anteriores, un build exitoso no garantiza que la pantalla funcione.
- Probar contra el presupuesto real de septiembre (sin inicializar) Y contra uno inicializado (ej. julio, tiene datos reales con categorías sobre presupuesto) — los dos estados tienen lógica de UI distinta, probar solo uno no alcanza.
- Editar una asignación real de prueba desde el editor nativo, confirmar en la web real (`finance.cd-co.com.py/budgets/...`) que el cambio se ve reflejado, y devolverla a su valor original antes de terminar (mismo criterio de no dejar basura de testing que se usó al verificar el backend hoy).
- Confirmar visualmente el layout responsivo en al menos 2 tamaños de pantalla/emulador (compacto y ancho) — es la primera vez que se prueba este patrón, no asumir que compila y ya funciona visualmente bien.

## Notas de implementación

- Orden sugerido: (1) DTOs extendidos + wiring del `BudgetDashboardViewModel` a los campos reales (reemplaza cualquier mock/placeholder que tenga hoy), (2) donut + tabs + lista de categorías con AppCard/colores reales (la pieza de solo-lectura, más simple), (3) responsividad del bloque superior (BoxWithConstraints), (4) detalle de categoría (reusa TransactionsScreen existente para "ver todas"), (5) editor de asignación (la pieza de escritura, la más compleja, depende de que (1)-(4) ya estén probadas).
- El backend YA está completo y deployado (PRs #233/#234/#235, mergeados y verificados en vivo contra producción hoy) — esta wave es 100% cliente nativo, no requiere tocar Rails.
- Nombres de campo del API calcados exactos en la sección de Arquitectura — no hace falta adivinar el shape, están verificados contra respuestas reales de producción.
