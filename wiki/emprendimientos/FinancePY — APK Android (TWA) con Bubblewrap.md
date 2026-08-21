---
type: emprendimiento
title: "FinancePY — APK Android (TWA) con Bubblewrap"
status: generado, pendiente de distribución real
created: 2026-08-07
updated: 2026-08-07
tags: [financespy, android, twa, pwa, mobile]
related:
  - "[[FinancePY - Hosting fase prueba (PC local)]]"
  - "[[Migración hosting FinancePY — análisis Cloudflare vs alternativas]]"
  - "[[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]]"
---

# FinancePY — APK Android (TWA) con Bubblewrap

> ⚠️ **Contradicción sin resolver**: una sesión previa (2026-08-05) había
> elegido **Capacitor** para esto (push nativo), no TWA — ver
> [[Sesión 2026-08-05 FinancePY offline-first Fase 1 (Capacitor)]]. Esta
> página documenta lo que efectivamente se construyó y firmó, pero nadie
> decidió a propósito descartar Capacitor. La capa de datos offline (specs
> de esa sesión) sigue siendo válida sin importar qué shell nativo gane.

## Qué es

FinancePY ya era instalable como PWA (manifest.json + service worker
completos, heredado del fork Sure). Esto empaqueta esa misma PWA en un
`.apk`/`.aab` real de Android usando **Trusted Web Activity (TWA)** vía
**Bubblewrap CLI** (herramienta oficial de Google) — sin reescribir nada,
sin segundo código base.

## Por qué no hacía falta Google AI Studio

Se evaluó como opción y se descartó: AI Studio es la consola de Gemini
(prompts, function calling), no tiene nada que ver con empaquetar apps
Android. Confusión inicial aclarada, sin consecuencia.

## Cómo se generó (reproducible)

Entorno: Mac sin Android Studio instalado previamente.

1. **JDK 17 portátil, sin sudo** — Homebrew pedía contraseña de sistema
   (pkg installer). Se bajó el tar.gz de Adoptium directo y se extrajo a
   `~/.local/jdk/`, sin tocar el Java del sistema (queda una JDK 8 vieja
   ahí, intacta).
2. `npm install @bubblewrap/cli` en un directorio nuevo
   (`~/code/financespy-twa`).
3. `bubblewrap init --manifest=https://finance.cd-co.com.py/manifest.json`
   — el wizard interactivo se cuelga fácil sin TTY real (pide nombre y
   apellido para el certificado, entre otras cosas). Mejor evitarlo con
   los pasos manuales de abajo si se repite esto.
4. **Keystore de firma** generado directo con `keytool` (evita el wizard):
   `keytool -genkeypair -keystore android.keystore -alias android -keyalg RSA -keysize 2048 -validity 10000 ...`
5. **Build sin prompts interactivos** — variables de entorno que
   Bubblewrap lee solo si están seteadas (evita los prompts de password
   que se cuelgan igual que el wizard):
   ```
   BUBBLEWRAP_KEYSTORE_PASSWORD=... BUBBLEWRAP_KEY_PASSWORD=... npx bubblewrap build
   ```
6. Genera `app-release-signed.apk` y `app-release-bundle.aab`.

## Datos del build

- **Package ID:** `py.com.cd_co.finance.twa`
- **Fingerprint SHA-256 del certificado:**
  `DD:BF:1F:55:E6:CD:0F:4F:6A:F9:18:40:DB:FA:EE:68:B7:4E:FE:7C:DD:6F:ED:F3:45:6B:CB:FA:55:76:BD:0A`
- **Keystore:** respaldado en Drive,
  `.local-secrets/android-keystores/financespy-twa-android.keystore`.
  **Contraseña no guardada en ningún archivo** — la tiene el usuario.
  ⚠️ Si se pierde este keystore, no se puede volver a firmar/actualizar
  esta app nunca más con la misma identidad — cualquier update futuro
  necesitaría un fingerprint nuevo, y los usuarios tendrían que
  desinstalar y reinstalar desde cero.
- **`.apk`/`.aab` finales:** quedaron en `~/Desktop/FinancePY-app/` en la
  Mac del usuario (no versionados, no están en git).

## Digital Asset Links (para pantalla completa sin barra de navegador)

Android necesita verificar que la app y el dominio son del mismo dueño.
Se agregó `public/.well-known/assetlinks.json` al repo (PR #65,
mergeado) con el package ID y el fingerprint de arriba.

**Sin cuenta de Google Play Console** (los $25 USD son solo para
publicar, no para generar el APK): funciona igual, por **sideload**
directo. Trade-offs de esa vía:
- Sin actualizaciones automáticas — cada cambio implica regenerar y
  redistribuir el `.apk` a mano.
- Android muestra advertencia de "app no verificada" al instalar (un tap
  extra, no bloquea).
- Sin listado público — solo llega a quien se le mande el link/archivo.

## Problema real encontrado y resuelto durante el build

`AndroidSdkTools.validatePath` (versión de Bubblewrap usada) busca una
carpeta `tools/` o `bin/` en la raíz del SDK — patrón legacy que los SDKs
modernos de Android Studio ya no crean (usan `cmdline-tools/`). Se
resolvió creando una carpeta vacía `tools/` en el SDK — el check es solo
de existencia, no usa nada de adentro, no rompe nada real del SDK.

## Pendiente

- [ ] Confirmar en el celular real que la app abre sin barra de Chrome
  (depende de que `assetlinks.json` sirva bien en producción — ver saga
  del Cache-Control en [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]])
- [ ] Definir canal de distribución real del `.apk` a los testers (Drive,
  link directo, etc.)
- [ ] Evaluar Play Console ($25 único) cuando el producto pase de fase de
  prueba a algo más público — resuelve las auto-actualizaciones y la
  advertencia de instalación
