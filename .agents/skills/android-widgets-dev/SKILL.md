---
name: android-widgets-dev
description: >-
  Guía y runbook para crear, modificar, compilar e instalar widgets nativos de
  pantalla de inicio en la app Android KMP (native/financespy-kmp) de Finance-PY.
  Usar al trabajar en widgets Android o al compilar/instalar la APK en el celular.
---

# Android Home Screen Widgets & Build (Finance-PY)

## Entorno local (macOS)
Las herramientas locales viven en `/Volumes/Hitachi 1/01 - Proyectos /tools/`:

```bash
export JAVA_HOME="/Volumes/Hitachi 1/01 - Proyectos /tools/jdk/jdk-17.0.21+9/Contents/Home"
export ANDROID_HOME="/Volumes/Hitachi 1/01 - Proyectos /tools/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

adb devices
cd "native/financespy-kmp" && ./gradlew :androidApp:installDebug
```

## Reglas obligatorias para Widgets Android
1. **Datos:** Leer el JSON cifrado de `AndroidDashboardCache` usando `org.json.JSONObject` (nativo de Android; `kotlinx-serialization-json` no está expuesto en `androidApp`). Evitar `continue`/`break` dentro de lambdas inline (Kotlin 2.1).
2. **Dinero líquido disponible:** Sumar únicamente cuentas líquidas (`depository`, `cash`, `checking`, `savings`) bajo `classification == "asset"`. **Nunca** hacer fallback a `net_worth` ni restar tarjetas de crédito.
3. **Redimensionado libre (One UI / Android):**
   - En `res/xml/widget_*_info.xml`: `minWidth="40dp"`, `minHeight="40dp"`, `minResizeWidth="40dp"`, `minResizeHeight="40dp"`, `targetCellWidth="2"`, `targetCellHeight="2"`, `resizeMode="horizontal|vertical"`, sin `maxResizeWidth`/`maxResizeHeight`.
   - Sobrescribir `onAppWidgetOptionsChanged` para alternar entre layout compacto (`2×2`) y extendido (`minWidthDp >= 220`).
4. **Diseño visual:** Tarjetas blancas (`#FFFFFF`) con esquinas `24dp`, borde `#E5E7EB`, barra verde (`#16A34A`) para líquido/disponible y roja (`#E11D48`) para pasivos/gastos.
5. **Auto-actualización:** Registrar todo nuevo `AppWidgetProvider` en `AndroidManifest.xml` y en `WidgetUpdater.updateAll(context)` (disparado automáticamente desde `AndroidDashboardCache.save`).

Referencia completa: `docs/widgets-implementation.md`.
