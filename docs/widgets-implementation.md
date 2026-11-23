# Implementación de Widgets en Finance-PY (Web Rails + Android Nativo)

Este documento resume la arquitectura, archivos implementados, decisiones técnicas y guía paso a paso para mantener o agregar nuevos widgets en **Finance-PY**, tanto en el dashboard web (Rails) como en la pantalla de inicio de Android (`native/financespy-kmp`).

---

## 1. Widgets del Dashboard Web (Rails + ViewComponent + Turbo Frames)

### Decisiones clave de arquitectura
- **Autenticación y permisos:** `Dashboard::WidgetsController` hereda de `ApplicationController` (que ya incluye `Authentication`, `RowLevelSecurity` y `AccountAuthorizable`). No se usa `authenticate_user!`. Todas las consultas respetan `Current.finance_accounts` para no exponer cuentas privadas de otros miembros de la familia.
- **Moneda y `Money` propio (`lib/money.rb`):** Se utiliza `Money.new(amount, currency)`, `#exchange_to` y `#format` (que formatea `PYG` sin decimales). Las sumas se realizan con `reduce(zero_money)` para evitar errores con colecciones vacías.
- **Modelos reales del dominio:**
  - **Cuentas líquidas:** `accountable_type: "Depository"` (no existe `"Cash"` en `Accountable::TYPES`).
  - **Presupuesto:** `Budget.find_or_bootstrap(family, start_date:, user:)` respetando `family.uses_custom_month_start?`.
  - **Ventas:** `family.sales.completed.includes(:sale_items)` para evitar N+1 y excluir borradores/canceladas.
- **Caché y diseño:** Cache keys versionadas con `family.accounts_cache_version` y estilos del Design System (`bg-container`, `shadow-border-xs`, `text-primary`, `text-secondary`).

### Archivos creados / modificados (Web)
- **Rutas:** `config/routes.rb` (`namespace :dashboard` → `resource :widgets`)
- **Controlador:** `app/controllers/dashboard/widgets_controller.rb`
- **Componente base:** `app/components/dashboard/base_widget_component.rb` (hereda de `ApplicationComponent`)
- **4 Widgets (`app/components/dashboard/`):**
  - `available_to_spend_component.rb` / `.html.erb`
  - `recent_expenses_component.rb` / `.html.erb`
  - `budget_status_component.rb` / `.html.erb`
  - `sales_summary_component.rb` / `.html.erb`
- **Vista Dashboard:** `app/views/pages/dashboard.html.erb` (grid responsivo de 4 `<turbo-frame loading="lazy">` con skeleton loaders)
- **Tests:**
  - `test/controllers/dashboard/widgets_controller_test.rb`
  - `test/components/dashboard/widgets_component_test.rb`

### Comandos de verificación (entorno Ruby 3.4.7)
```bash
bin/rails test test/controllers/dashboard/widgets_controller_test.rb test/components/dashboard/widgets_component_test.rb
bin/rubocop app/controllers/dashboard/widgets_controller.rb app/components/dashboard/ test/controllers/dashboard/widgets_controller_test.rb test/components/dashboard/widgets_component_test.rb
```

---

## 2. Widgets Nativos de Pantalla de Inicio (Android / KMP)

### Decisiones clave de arquitectura
- **Fuente de datos sin latencia ni dependencias extra:** Los widgets leen directamente el JSON cifrado del dashboard guardado en `AndroidDashboardCache` (`EncryptedSharedPreferences`, aislado por `OwnerScope`), parseado con `org.json.JSONObject` (nativo de Android, sin exponer `kotlinx-serialization-json` en `androidApp`).
- **Actualización automática:** Cada vez que `AndroidDashboardCache.save(...)` guarda un dashboard nuevo, dispara `WidgetUpdater.updateAll(appContext)` para refrescar todos los widgets activos en la pantalla de inicio.
- **Dinero líquido real (sin fallback a patrimonio neto):** `BalanceWidgetProvider` suma únicamente las cuentas líquidas de activos (`depository`, `cash`, `checking`, `savings`), mostrando siempre **Líquido disponible** y nunca sustituyéndolo por el patrimonio neto.
- **Redimensionado libre (Samsung One UI / Android):**
  - `minWidth="40dp"`, `minHeight="40dp"`, `minResizeWidth="40dp"`, `minResizeHeight="40dp"`, sin `maxResizeWidth`/`maxResizeHeight` y con `resizeMode="horizontal|vertical"`.
  - Esto permite achicar o estirar libremente desde 1×1, 2×1, 2×2 hasta 4×2 o más.
  - `onAppWidgetOptionsChanged` detecta `OPTION_APPWIDGET_MIN_WIDTH >= 220` (dp) para alternar automáticamente entre el layout compacto (`2×2`) y el layout extendido (`4×2`).
- **Estilo visual:** Tarjetas blancas redondeadas (`24dp`), borde sutil (`#E5E7EB`), tipografía de alto contraste, barras de progreso verde (`#16A34A`) para líquido/disponible y rojo (`#E11D48`) para pasivos/gastos.

### Archivos creados / modificados (Android)
- **Lógica y actualización:**
  - `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/widgets/WidgetDataLoader.kt` (`WidgetSnapshot`, `WidgetDataLoader`, `WidgetUpdater`)
  - `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/widgets/BalanceWidgetProvider.kt`
  - `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/widgets/ExpensesWidgetProvider.kt`
  - `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/cache/AndroidDashboardCache.kt` (hook a `WidgetUpdater.updateAll`)
- **Layouts y recursos:**
  - `native/financespy-kmp/androidApp/src/main/res/drawable/widget_background.xml`
  - `native/financespy-kmp/androidApp/src/main/res/drawable/widget_progress_green.xml`
  - `native/financespy-kmp/androidApp/src/main/res/drawable/widget_progress_red.xml`
  - `native/financespy-kmp/androidApp/src/main/res/layout/widget_balance.xml` (compacto)
  - `native/financespy-kmp/androidApp/src/main/res/layout/widget_balance_wide.xml` (extendido)
  - `native/financespy-kmp/androidApp/src/main/res/layout/widget_expenses.xml` (compacto)
  - `native/financespy-kmp/androidApp/src/main/res/layout/widget_expenses_wide.xml` (extendido)
  - `native/financespy-kmp/androidApp/src/main/res/xml/widget_balance_info.xml`
  - `native/financespy-kmp/androidApp/src/main/res/xml/widget_expenses_info.xml`
- **Manifiesto:** `native/financespy-kmp/androidApp/src/main/AndroidManifest.xml` (registro de ambos `<receiver>`)

---

## 3. Cómo compilar e instalar en el celular (Entorno local)

Las herramientas locales en esta Mac están en `/Volumes/Hitachi 1/01 - Proyectos /tools/`:

```bash
export JAVA_HOME="/Volumes/Hitachi 1/01 - Proyectos /tools/jdk/jdk-17.0.21+9/Contents/Home"
export ANDROID_HOME="/Volumes/Hitachi 1/01 - Proyectos /tools/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

# Verificar celular conectado
adb devices

# Compilar e instalar debug en el dispositivo conectado
cd "native/financespy-kmp" && ./gradlew :androidApp:installDebug
```

---

## 4. Indicaciones para agregar nuevos widgets en el futuro

### Para un nuevo widget Android
1. **Datos:** Agregar el campo necesario a `WidgetSnapshot` y parsearlo en `WidgetDataLoader.loadSnapshot(context)` (usando `org.json.JSONObject`, sin `continue` dentro de lambdas inline por compatibilidad con Kotlin 2.1).
2. **Layouts:** Crear `widget_<nombre>.xml` (compacto) y `widget_<nombre>_wide.xml` (extendido) usando `@drawable/widget_background`.
3. **Configuración (`res/xml/widget_<nombre>_info.xml`):** Usar `minWidth="40dp"`, `minHeight="40dp"`, `minResizeWidth="40dp"`, `minResizeHeight="40dp"`, `resizeMode="horizontal|vertical"` y sin `maxResizeWidth`/`maxResizeHeight`.
4. **Provider:** Crear `<Nombre>WidgetProvider : AppWidgetProvider()` sobrescribiendo `onUpdate` y `onAppWidgetOptionsChanged`.
5. **Registro:** Declarar el `<receiver>` en `AndroidManifest.xml` y agregar la clase a `WidgetUpdater.updateAll(...)`.
6. **Instalación:** Ejecutar `./gradlew :androidApp:installDebug` y probar redimensionando en el celular (si se cambian límites `minResize*`, quitar y volver a agregar el widget en la pantalla de inicio).

### Para un nuevo widget Web (Rails)
1. Crear el `ViewComponent` heredando de `Dashboard::BaseWidgetComponent` en `app/components/dashboard/`.
2. Agregar la ruta en `config/routes.rb` bajo `namespace :dashboard` → `resource :widgets` y la acción en `Dashboard::WidgetsController`.
3. Incluir el `<turbo-frame loading="lazy">` en `app/views/pages/dashboard.html.erb`.
4. Agregar tests en `test/controllers/dashboard/widgets_controller_test.rb` y `test/components/dashboard/widgets_component_test.rb`.
