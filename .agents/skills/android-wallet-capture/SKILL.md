---
name: android-wallet-capture
description: >-
  Runbook de diagnóstico ADB, invariantes de confiabilidad y flujo de deploy para
  la captura automática de notificaciones bancarias (Conti, Ueno, GNB, Itaú) y
  Google Wallet en la app Android KMP (native/financespy-kmp) de Finance-PY.
  Usar cuando falte una transacción capturada, falle la ubicación en segundo plano
  o se modifiquen extractores/webhooks de notificaciones.
---

# Android Wallet & Bank Notification Capture (Finance-PY)

## Diagnóstico rápido vía ADB (cuando falta una transacción)
```bash
ADB="/Volumes/Hitachi 1/01 - Proyectos /tools/android-sdk/platform-tools/adb"
"$ADB" devices

# 1. Ver notificaciones recientes (sin censurar texto)
"$ADB" shell dumpsys notification --noredact | awk '
/NotificationRecord.*(com\.google\.android\.apps\.messaging|py\.com\.bancontinental\.contiapp|com\.google\.android\.apps\.walletnfcrel|py\.com\.elcomercio\.retailbanking)/ {p=1; c=0}
p {print; c++; if (c>45) p=0}
'

# 2. Ver estado de cola local, partes vistas y auth prefs (app dev)
"$ADB" shell "run-as py.com.cdco.financespy.dev ls -la shared_prefs/wallet_pending_captures.xml shared_prefs/wallet_seen_notification_parts.xml shared_prefs/financespy_auth_prefs.xml"

# 3. Ver logs de captura y permisos de ubicación en segundo plano
"$ADB" logcat -d -s WalletCaptureHandler:V | tail -n 40
"$ADB" shell dumpsys package py.com.cdco.financespy.dev | grep -i "ACCESS_BACKGROUND_LOCATION: granted"
```

## Invariantes obligatorios del pipeline
1. **Write-Ahead Queue (Samsung `FreecessController`):** Samsung One UI congela procesos en segundo plano ~6s después de descongelarlos por `INotificationListener`. Toda compra extraída **debe persistirse en `PendingCaptureStore` inmediatamente**, antes de pedir GPS (timeout ≤ 3s) o hacer llamadas HTTP, y solo eliminarse tras `WebhookResult.Success`.
2. **Refresh automático de OAuth (Doorkeeper TTL 2h):** `WebhookClient` / `WalletCaptureHandler` deben refrescar el `access_token` con `refresh_token` ante cualquier `401` (verificando antes si `ApiClient` ya lo rotó en paralelo) y reintentar el `POST`.
3. **Regex de Google Wallet (`\u00A0` NBSP):** Google Wallet envía montos como `Gs.\u00A049.938 con Amex Gold ••2269`. En Java/Kotlin `Regex`, `\s` **no** matchea `\u00A0`; usar siempre `[\s\u00A0]` y soportar `PYG`, `Gs.`, `₲` y `con`/`with`.
4. **Ubicación en segundo plano y UI estilo Apple/Google Pay:**
   - `WalletLocationPreferences.isLocationCaptureEnabled()` se auto-habilita si el usuario ya otorgó `ACCESS_BACKGROUND_LOCATION` + `ACCESS_FINE/COARSE_LOCATION` en Android y no apagó explícitamente el switch en Settings.
   - `WalletCaptureHandler.fetchLocationBestEffort` usa estrategia rápida para interiores dentro de la ventana Samsung (~6s): `getCurrentLocation` (`HIGH_ACCURACY`, caché ≤ 2 min, timeout 2.5s) → fallback a `lastLocation` (≤ 15 min) → fallback `BALANCED_POWER_ACCURACY` (Wi-Fi/red, 1s). Verificar logs en `WalletCaptureHandler:V` y permiso `ACCESS_BACKGROUND_LOCATION: granted=true`.
   - En la UI (`TransactionLocationMap.kt` y `app/views/transactions/show.html.erb`), mostrar una sola tarjeta limpia estilo Apple Pay / Google Pay ("Ubicación de la operación", mapa con pin y enlace "Ver en Maps", sin duplicar `TransactionLocationMap` en `TransactionFormScreen`).
5. **No re-disparo retroactivo:** `NotificationListenerService.onNotificationPosted` solo corre para notificaciones nuevas; actualizar la APK no re-procesa notificaciones que ya estaban en la barra antes de instalar.
6. **Filtrado de mensajes históricos en hilos SMS (`android.messages`):** `SeenNotificationPartsStore` expira a las 6h para no bloquear compras reales repetidas en días distintos, pero los hilos `MessagingStyle` conservan SMS sin descartar durante días y los re-publican cuando llega un SMS nuevo. `WalletNotificationListenerService` (`extractNotificationParts`) debe descartar entradas de `android.messages` con antigüedad `> 6h`.
7. **Deduplicación backend resistente a renombrados:** `AndroidPurchase::WebhookProcessor#duplicate_entry_exists?` busca en `±1 día` sobre la misma cuenta y monto verificando `name == description`, `extra["merchant"] + extra["item"]` o `extra["raw_text"]` (para no duplicar si el usuario o una Rule renombró la entrada original).
8. **Conciliación bidireccional con Flota (`FuelLog`):** Si ya existe un `FuelLog` en la misma cuenta/monto/`±1 día`, el webhook responde `:duplicate`; a la inversa, `FuelLog#create_associated_entry` vincula y actualiza una entrada `google_play` previa sin `fuel_log` en lugar de crear una segunda entrada (`Combustible - <placa>`). Estaciones confirmadas en `FUEL_MERCHANT_KEYWORDS` incluyen `COMBU BAR`.

## Build, instalación y deploy
- **En el celular del usuario se instala la APK `dev` (`py.com.cdco.financespy.dev`):**
  ```bash
  export JAVA_HOME=$(ls -d "/Volumes/Hitachi 1/01 - Proyectos /tools/jdk"/*/Contents/Home | head -n 1)
  export ANDROID_HOME="/Volumes/Hitachi 1/01 - Proyectos /tools/android-sdk"
  export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
  cd "native/financespy-kmp" && ./gradlew :androidApp:testDebugUnitTest :androidApp:installDebug --no-daemon
  ```
- **Deploy a producción:** `main` es rama protegida (exige PR). Subir en rama nueva → PR + Merge a `main` → GitHub Actions `FinancePY Android Build` (`workflow_dispatch`, `buildType: release`). El repo `fabriziocorbeta/Finance-PY` es **público**.
