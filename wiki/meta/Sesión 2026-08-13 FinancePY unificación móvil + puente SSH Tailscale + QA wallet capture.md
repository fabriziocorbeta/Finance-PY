---
type: session
title: "Sesión 2026-08-13 FinancePY — unificación móvil (Capacitor+Wallet), puente SSH/Tailscale, QA en curso"
created: 2026-08-13
updated: 2026-08-14
tags: [financespy, android, capacitor, wallet, tailscale, ssh, wsl, qa, sesion]
status: en-curso
related:
  - "[[Sesión 2026-08-11-12 FinancePY RN app login OAuth resuelto]]"
  - "[[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]]"
  - "[[FinancePY — APK Android (TWA) con Bubblewrap]]"
  - "[[financespy]]"
---

# Sesión 2026-08-13 — FinancePY: unificación móvil, puente SSH/Tailscale, QA wallet capture

## Resumen

Esta sesión retoma la fragmentación de 3 iniciativas móviles detectada el 2026-08-11/12 (TWA, Capacitor offline-first, RN app). Rama `feature/android-unified-wallet-capture` (repo `cd-co-erp`, PR #70) une Capacitor v6 + `WalletNotificationListenerService` nativo (Kotlin) — la captura Wallet que antes vivía solo en el RN app separado ahora está integrada al shell Capacitor. TWA/Bubblewrap queda fuera sin decisión formal de descarte.

## Build: 100% CLI en WSL, Android Studio explícitamente descartado

El usuario aclaró que no trabajan nunca con Android Studio (GUI) — todo el build se resolvió por línea de comandos:

- **JDK 17 → 21**: el Capacitor/plugin actual requiere `source release 21`, no 17.
- **Android SDK instalado nativo dentro de WSL2 Ubuntu** (`~/Android/Sdk`: cmdline-tools + platform 34/35/36 + build-tools) — evita cruzar filesystems WSL↔Windows. El primer intento (`gradlew.bat` vía `\\wsl$\Ubuntu\...` desde PowerShell) falla porque `cmd.exe` rechaza rutas UNC como directorio de trabajo.
- `./gradlew assembleDebug` corre limpio desde WSL puro, sin tocar Windows para nada del build.
- Parches nativos manuales confirmados ya commiteados en la rama (no hizo falta re-aplicarlos): `registerPlugin(WalletListenerPlugin.class)` en `MainActivity.java`, `<service>` en `AndroidManifest.xml`. `secrets.xml` (token webhook) gitignored, como corresponde.

## Puente Mac↔notebook: Tailscale + SSH, verificado real

Se armó un túnel directo para eliminar el relay manual de copy-paste de logs/código entre la Mac y la notebook:

- Tailnet `fabriziocorbeta@gmail.com`. Mac `100.69.204.63` (`macbook-pro-von-fabrizio`), notebook `100.105.31.71` (`desktop-do9f6fq`, WSL Ubuntu, usuario `fabrizio`).
- SSH server en WSL arrancado con `sudo service ssh start` — **systemd no está activo en esa instalación WSL**, `systemctl enable --now ssh` no arranca nada de verdad ahí (falla silenciosa). Para systemd real hace falta `[boot]\nsystemd=true` en `/etc/wsl.conf` + `wsl --shutdown`.
- Auth por key: se reusó `~/.ssh/id_ed25519.pub` ya existente de la Mac, agregada a `authorized_keys` de la notebook.
- **Confirmado con comando real desde la sesión de Claude** (`ssh -o BatchMode=yes fabrizio@100.105.31.71 'hostname && whoami && pwd'`), no asumido del reporte del usuario — el primer intento con `BatchMode=yes` efectivamente rebotó con `Permission denied (publickey,password)` antes de agregar la key, confirmando que el paso era necesario y no solo teatro.
- Notebook configurada para no suspender al cerrar la tapa (Panel de control → Energía → "qué hace el cierre de la tapa" → No hacer nada, conectada a corriente) — el puente sobrevive con la notebook cerrada.

## Patrón reforzado (tercera vez, ver ya sesión 2026-08-07/08): no confiar en reportes de Gemini sin verificar

Dos veces en esta misma sesión un paso reportado por Gemini (que el usuario usa como copiloto en la notebook) como "perfecto"/"correcto" tenía un problema real al verificarlo:

1. `MainActivity.java` "corregido" — faltaba el `import py.com.cdco.financespy.wallet.WalletListenerPlugin;`, hubiera fallado compilación.
2. SSH "entré perfecto, sin password" — en los hechos, la key todavía no estaba autorizada; verificado con `BatchMode=yes` desde la sesión de Claude, que rebotó hasta que se agregó la key de verdad.

Ver [[feedback_verify_before_fixing]] (memoria) — mismo patrón ya documentado en la sesión de OAuth del 11-12/08, ahora con dos instancias más.

## QA en curso — checklist de 6 casos, 2 bugs reales encontrados

Permiso de acceso a notificaciones confirmado otorgado (Ajustes → Acceso a notificaciones → FinancePYApp: activado) — descartado como causa de los bugs de captura.

1. **Modo avión — pantalla dura, no fallback**: `capacitor.config.json` tiene `server.url: "https://finance.cd-co.com.py"` (no sirve `webDir` local embebido) — el WebView navega directo al remoto. La pantalla mostrada era branded (logo FinancePY, no el dino de Chrome), sugiriendo que el Service Worker sí intercepta pero no tiene manejo rico para este caso. Los archivos de la Fase 1 offline-first (`offline_sales_db.js`, `offline_transactions_sync.js`, `offline_transactions_db.js`) **sí están presentes en esta rama** — pendiente confirmar si el gap es de UI (falta wire-up de la pantalla offline) o de lógica, contra `docs/superpowers/plans/2026-08-12-financespy-mobile-unificacion-capacitor.md`.
2. **Compra Google Wallet/Ueno no detectada**: `WalletNotificationListenerService.kt` (`android/app/src/main/java/py/com/cdco/financespy/wallet/`) filtra por un único paquete hardcodeado `com.google.android.apps.walletnfcrel`, sin logging de paquetes descartados. Sospecha: mismatch entre ese valor y el paquete real que posteó la notificación de la compra. Diagnóstico pedido (`adb shell dumpsys notification --noredact`), sin confirmar aún al cierre de esta nota.

Tests 1 (login persiste), 3 (background), 5 (sync sin duplicados) y 6 (tarjeta no reconocida) del checklist: no ejecutados todavía.

## Housekeeping de repo

`package-lock.json` tenía un diff real de 1125 líneas (drift normal de `npm install` durante el setup del build, `package.json` sin cambios) — commiteado y pusheado (`0e2685f`) directo desde la sesión de Claude vía el puente SSH. `battery-report.html` y `cloudflared.deb` sueltos en el working dir de la notebook: identificados como basura no relacionada, no tocados.

## Cierre: CI real arreglado (no solo lint), PR #70 mergeada

El ci-monitor flagueó `ci / scan_ruby` (Brakeman) fallando en PR #70. Investigado por SSH sin pedirle nada al usuario:

- **Bug real, no solo Brakeman**: `ANDROID_WEBHOOK_TOKEN`/`ANDROID_WEBHOOK_FAMILY_ID` estaban en `.env.local` pero ausentes del whitelist `x-rails-env` de `compose.local.yml` (mismo patrón recurrente del repo, ya visto 3 veces antes). El webhook `/webhooks/android_purchase` devolvía 503 siempre — candidato fuerte a explicar el bug #2 de QA (compra Ueno no detectada). Fix wireado y verificado en vivo (curl: 401 en vez de 503 antes/después).
- `ANDROID_WEBHOOK_FAMILY_ID` es lo que habilita el scoping anti-IDOR en `AndroidPurchase::WebhookProcessor` — sin esa var, el mass-assignment que Brakeman marcó en `webhooks_controller.rb` era una vulnerabilidad real (cualquiera con el token podía escribir en cualquier account_id de cualquier familia), no falso positivo. El ignore de Brakeman se agregó recién después de confirmar el fix, no antes.
- Fingerprint de `brakeman.ignore` para el warning EOLRails (Rails 7.2, EOL 2026-08-09) estaba obsoleto por un cambio de tiempo verbal en el mensaje de Brakeman ("ends"→"ended") — corregido.
- **`ci / test` falló aparte, sin relación con esta PR**: `SettingsTest#test_can_update_self_hosting_settings` — archivo idéntico a `main`, reproducido 2/2 en CI. Investigación descartó la teoría previa de "leak entre workers paralelos" (`test:system` corre con `DISABLE_PARALLELIZATION=true`, secuencial) — hipótesis revisada apunta a teardown de Mocha interrumpido por timing de Selenium en CI, sin confirmar al 100%. Documentado como [issue #71](https://github.com/fabriziocorbeta/cd-co-erp/issues/71) en vez de bloquear.
- **PR #70 mergeada** con `gh pr merge --admin` (decisión explícita del usuario, branch protection `enforce_admins: false`) — commit `8365872` a `main`.

## Continuación 2026-08-14 — fixes en rama equivocada, código Kotlin recuperado, 2 bugs reales más

Tras el merge de PR #70, la notebook quedó sin querer parada en `feature/android-offline-phase1` (vieja, 17 commits atrás de `main`) — ahí cayeron 2 fixes reales (script de linking, bug de signo del webhook) en vez de en `main`. Detectado porque un fuel log nuevo de esta sesión quedó sin categorizar mientras uno viejo sí tenía "Combustible" automático (`main` tiene ese fix, la rama vieja no) — la comparación llevó a encontrar el desvío de rama.

**Hallazgo más grave: todo el código Kotlin del wallet capture nunca estuvo versionado en git, en ningún lado.** `native/android/wallet-listener/` (la fuente de verdad que el script de linking siempre asumió que existía) nunca se creó — los 7 `.kt` + el manifest-snippet vivían solo sueltos, sin commitear, dentro del `android/` gitignoreado de la notebook. Recuperado del working copy (que venía compilando y capturando compras reales toda la sesión) y commiteado a `main` — sin esto, perder el disco de la notebook hubiera borrado la implementación entera sin rastro.

**Fixes movidos correctamente a `main` vía cherry-pick:** script de linking + signo income→expense del webhook.

**Bug real nuevo — duplicados de Wallet capture:** confirmado con datos reales (2 transacciones idénticas creadas con 2 segundos de diferencia, `external_id` distinto cada una — no era problema de idempotencia del server, eran 2 POSTs genuinamente separados). Causa: Google Wallet postea la notificación y la actualiza con el mismo texto poco después, `onNotificationPosted` se dispara de nuevo sin que el código supiera "ya vi esto". Fix: dedup de 60 segundos por contenido exacto en `WalletCaptureHandler`. Duplicado real ya creado, borrado a mano.

**Feature agregada — auto-categorización de wallet capture:** en vez de lógica nueva, se enganchó al motor de Rules ya existente de la app (mismo que usa `Settings > Rules` para todo el resto de transacciones) — dispara `RuleJob` para las reglas activas de la familia después de crear cada entry capturada, con `rescue` para que un bug de reglas nunca rompa la captura real de la compra.

**Nota operativa:** un corte transitorio de SSH ("Connection reset by peer") durante un rebuild de Docker no abortó el build — el daemon Docker sigue trabajando server-side independiente de si la sesión que mira el output sigue viva. Verificar el estado real (grep en el container) antes de asumir que hay que re-lanzar algo.

**Pendiente al cierre:** backend en `main` con los 3 fixes activos y verificados en el container real; APK con el fix de dedup rebuildeado y subido a Drive. Falta que el usuario confirme, con una compra real nueva, que ya no se duplica y que categoriza sola (si hay una rule activa para ese merchant).

## Ver también

- [[Sesión 2026-08-11-12 FinancePY RN app login OAuth resuelto]] — origen de las 3 iniciativas móviles sin decisión
- [[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]] — origen de la Fase 1 offline (iniciativa B)
- [[FinancePY — APK Android (TWA) con Bubblewrap]] — iniciativa A, sigue sin decisión formal de descarte
- [[financespy]] — nota principal del proyecto
