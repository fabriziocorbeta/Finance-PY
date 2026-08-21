---
title: "Navegación móvil personalizable (bottom-nav) — FinancePY"
created: 2026-08-18
status: approved
related:
  - "docs/superpowers/specs/2026-08-17-financespy-cuentas-a-cobrar-design.md"
---

# Navegación móvil personalizable (bottom-nav) — FinancePY

## Contexto y objetivo

Surgió al mostrar screenshots de mibilletera.online (sidebar hamburguesa + bottom-nav de 4 iconos fijos + botón "Más" con hoja desplegable) como inspiración para que la pantalla del celular se vea más pulcra al agregar Cuentas a Cobrar (spec [[2026-08-17-financespy-cuentas-a-cobrar-design]]). El usuario rechazó copiar ese layout fijo y pidió en cambio que el bottom-nav sea **reordenable por gustos de usuario** — no un layout hardcodeado como el de la referencia.

Exploración del código reveló que FinancePY **ya tiene** la pieza que mibilletera resuelve con su botón "Más": un drawer hamburguesa móvil (`data-action="app-layout#openMobileSidebar"`, botón arriba a la izquierda) que abre la lista completa de navegación. No hace falta construir esa superficie — ya existe. Este spec cubre solo la otra mitad: dejar que el usuario elija qué subset de esos ítems quiere fijo en el bottom-nav, y en qué orden.

**Corrección de una imprecisión propia durante el brainstorming**: se citó un comentario del código ("no atestar los 5 tabs core") como si describiera el estado actual, pero el array real `mobile_nav_items` en `app/views/layouts/application.html.erb` tiene **6** entradas hoy (Inicio, Transacciones, Reportes, Presupuestos, Metas, Asistente) — el comentario es aspiracional/desactualizado, no una descripción exacta. El diseño de abajo usa el conteo real.

## Alcance (confirmado con el usuario)

- El usuario elige **cuáles** ítems van en su bottom-nav y **en qué orden** — no hay un botón "Más" nuevo, el drawer hamburguesa ya existente cumple ese rol.
- Configuración vive en una pantalla nueva dentro de Configuración → Preferencias (ya existente).
- Cantidad de ítems **variable**: mínimo 3, máximo 6 (menos de 3 no tiene sentido como barra; más de 6 se ve apretado en pantallas angostas).
- Preferencia **por usuario**, no por familia — cada miembro (ej. la pareja del usuario, que recién empieza a usar la app) tiene su propio bottom-nav.
- Candidatos seleccionables: los 5 ítems finance-only actuales (Inicio, Transacciones, Reportes, Presupuestos, Metas) + Cuentas a Cobrar (una vez implementado ese spec) = **6 candidatos**.
- **"Asistente" queda fuera del set customizable, sin tocar su comportamiento actual** — no fue parte de la conversación de diseño, cambiar su visibilidad/acceso es una decisión de producto aparte que no se tomó acá. Sigue siempre presente en el bottom-nav exactamente como hoy, además de los ítems que el usuario elija.
- Sidebar desktop y el drawer hamburguesa móvil (ya existente) **no cambian** — siguen mostrando la lista completa fija, sin personalización. Solo el bottom-nav de 4-a-6 iconos en pantallas `lg:hidden` se vuelve curado.
- Comportamiento por defecto (usuarios existentes, antes de tocar la nueva pantalla de settings): el bottom-nav se ve **exactamente igual que hoy** — Inicio, Transacciones, Reportes, Presupuestos, Metas, en ese orden. Nadie ve su navegación cambiar sola al desplegar esto.

Fuera de alcance explícito (YAGNI):
- Botón "Más"/hoja desplegable nueva — el drawer hamburguesa ya existente cumple esa función.
- Tocar el comportamiento de "Asistente" (visibilidad, si es o no personalizable) — explícitamente no decidido, queda pinneado como está.
- Personalizar el sidebar desktop o el contenido del drawer hamburguesa — ambos siguen mostrando todo, sin cambios.
- Módulos de negocio (Inventario/Ventas/Pedidos/Flota) como candidatos — hoy son desktop-only por decisión ya tomada en el código (comentario explícito al respecto), no se revisita acá.
- Iconos custom por usuario, temas, o cualquier otra personalización visual más allá de qué-va-y-en-qué-orden.

## Arquitectura

Cero tablas nuevas. Reusa `users.preferences` (columna `jsonb`, default `{}`, ya existe) con una clave nueva `"bottom_nav_items"` — mismo mecanismo que ya usan `dashboard_section_order` y `reports_section_order` en `app/models/user.rb`. Reusa también el patrón de UI de esas dos features: un Stimulus controller de drag-reorder dedicado (mismo patrón que `dashboard_sortable_controller.js`, no una abstracción compartida nueva — el proyecto ya tiene 2 precedentes de "un sortable controller por feature", se sigue esa convención en vez de introducir una genérica).

### Lista maestra de candidatos

`app/views/layouts/application.html.erb`, se extrae la lista de items finance-only a una estructura con `key` estable (hoy están inline en el array `mobile_nav_items` sin key, solo con `path`/`icon`/`name`):

```ruby
<% nav_item_definitions = {
  "dashboard"    => { name: t(".nav.home"), path: root_path, icon: "pie-chart" },
  "transactions" => { name: t(".nav.transactions"), path: transactions_path, icon: "credit-card" },
  "reports"      => { name: t(".nav.reports"), path: reports_path, icon: "chart-bar" },
  "budgets"      => { name: t(".nav.budgets"), path: budgets_path, icon: "map" },
  "goals"        => { name: t(".nav.goals"), path: goals_path, icon: "target" },
  "receivables"  => { name: t("receivables.dashboard.title"), path: receivables_path, icon: "hand-heart" }
} %>
```

`mobile_nav_items` (usado hoy para desktop sidebar vía `desktop_nav_items = mobile_nav_items.reject { |item| item[:mobile_only] } + business_nav_items`) **se mantiene sin cambios**, construido a partir de `nav_item_definitions.values` en el orden fijo de siempre + el item de Asistente — el sidebar desktop no se toca.

Nueva variable, solo para el loop del bottom-nav (`<nav class="lg:hidden fixed bottom-0 ...">`, línea ~239):

```ruby
<% bottom_nav_items = Current.user.bottom_nav_items.filter_map { |key| nav_item_definitions[key]&.merge(active: page_active?(nav_item_definitions[key][:path])) } %>
<% bottom_nav_items << { name: t(".nav.assistant"), path: chats_path, icon: "icon-assistant", icon_custom: true, active: page_active?(chats_path) } %>
```

```erb
<%= tag.nav class: "...", data: { viewport_target: "bottomNav" } do %>
  <% bottom_nav_items.each do |nav_item| %>
    <%= render "layouts/shared/nav_item", **nav_item %>
  <% end %>
<% end %>
```

(`filter_map` descarta con seguridad cualquier key guardada que ya no exista en `nav_item_definitions` — ej. si algún día se elimina un item del set de candidatos, usuarios con esa key vieja en su preferencia no rompen la página, simplemente ese ítem desaparece de su bottom-nav.)

### Modelo — `app/models/user.rb`

Mismo patrón exacto que `dashboard_section_order` / `update_dashboard_preferences` (líneas 298-323 actuales):

```ruby
DEFAULT_BOTTOM_NAV_ITEMS = %w[dashboard transactions reports budgets goals].freeze

def bottom_nav_items
  preferences&.[]("bottom_nav_items") || DEFAULT_BOTTOM_NAV_ITEMS
end

def update_bottom_nav_preferences(keys)
  keys = keys.map(&:to_s) & (DEFAULT_BOTTOM_NAV_ITEMS + %w[receivables]) # solo keys válidas, sin duplicar validación de la lista maestra en dos lugares
  return false unless keys.size.between?(3, 6)

  transaction do
    lock!
    update!(preferences: (preferences || {}).deep_dup.merge("bottom_nav_items" => keys))
  end
end
```

### Controller y ruta

`app/controllers/settings/preferences_controller.rb`, agregar acción (mismo controller ya usado para la pantalla de Preferencias):

```ruby
def update_bottom_nav
  if Current.user.update_bottom_nav_preferences(bottom_nav_params)
    head :ok
  else
    head :unprocessable_entity
  end
end

private

def bottom_nav_params
  params.require(:bottom_nav_items)
end
```

`config/routes.rb`, junto a `resource :preferences, only: :show` (línea 194 actual):

```ruby
namespace :settings do
  resource :preferences, only: :show do
    patch :update_bottom_nav, on: :collection
  end
  # ...resto sin cambios
end
```

### Vista de configuración

`app/views/settings/preferences/show.html.erb`, nueva sección "Navegación": lista de los 6 candidatos (`nav_item_definitions`, mismo hash reusado — se mueve a un helper compartido, ej. `NavigationHelper#nav_item_definitions`, para no duplicarlo entre el layout y esta vista), cada fila con un checkbox (tildado = visible en el bottom-nav) + drag handle. El orden visual de las filas tildadas, de arriba hacia abajo, es el orden que se guarda.

```erb
<div data-controller="bottom-nav-sortable">
  <% nav_item_definitions.each do |key, item| %>
    <div data-bottom-nav-sortable-target="section" data-nav-key="<%= key %>" draggable="true">
      <%= check_box_tag "bottom_nav_items[]", key, Current.user.bottom_nav_items.include?(key),
            data: { action: "change->bottom-nav-sortable#saveOrder" } %>
      <%= icon(item[:icon]) %> <%= item[:name] %>
      <span data-bottom-nav-sortable-target="handle">⠿</span>
    </div>
  <% end %>
</div>
```

### Stimulus — `app/javascript/controllers/bottom_nav_sortable_controller.js`

Clon de `dashboard_sortable_controller.js` (drag mouse/touch/teclado con accesibilidad ya resuelta ahí), con dos diferencias puntuales:
- `saveOrder()` recolecta solo las filas con el checkbox tildado (`this.sectionTargets.filter(s => s.querySelector('input[type=checkbox]').checked)`), en su orden visual actual.
- El `fetch` apunta a `/settings/preferences/update_bottom_nav` con body `{ bottom_nav_items: order }` en vez de `/dashboard/preferences` con `{ preferences: { section_order: order } }`.
- Al tildar/destildar un checkbox (evento `change`, no solo drag) también dispara `saveOrder()` — a diferencia del dashboard (que solo reordena, nunca oculta secciones), acá agregar/quitar un ítem del set visible es una acción tan frecuente como reordenar.
- Antes de guardar, si el conteo de tildados queda fuera de 3-6, no se envía el request y se deshabilita momentáneamente el checkbox que causaría salirse del rango (con un tooltip/mensaje corto) — validación de UX en el cliente, la del servidor (`between?(3, 6)` en el modelo) es la que realmente protege el dato.

## Testing

Sigue el patrón existente del proyecto (Minitest):

- `test/models/user_test.rb` (extender, no crear archivo nuevo): `bottom_nav_items` sin preferencia guardada devuelve `DEFAULT_BOTTOM_NAV_ITEMS`; `update_bottom_nav_preferences` con 2 keys falla (menos de 3); con 7 keys falla (más de 6); con keys inválidas las filtra sin fallar; con 3-6 keys válidas persiste y se refleja en `bottom_nav_items`.
- `test/controllers/settings/preferences_controller_test.rb` (extender): `PATCH update_bottom_nav` con params válidos devuelve 200 y persiste; con params fuera de rango devuelve 422.
- Test manual: entrar a Configuración → Preferencias → Navegación, destildar "Metas", arrastrar "Cuentas a Cobrar" arriba de todo, confirmar que el bottom-nav real (abajo de la pantalla, en mobile) refleja el cambio sin recargar la página a mano, y que sigue así tras cerrar y reabrir la app. Confirmar que el sidebar desktop y el drawer hamburguesa siguen mostrando todo, sin cambios.
