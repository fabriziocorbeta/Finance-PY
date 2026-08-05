# FinancePY — App Android (Capacitor)

Genera un APK instalable que envuelve la app Rails existente. La config ya
está lista en `capacitor.config.json`; estos son los pasos que faltan, que
requieren Android Studio y por eso se corren a mano.

## Qué hace esta config

Capacitor en **modo remoto** (`server.url`): el shell nativo abre el sitio
real en un WebView, no empaqueta assets. Es el patrón que Ionic documenta
para apps server-renderizadas (Rails/Django/PHP) que no shippean como bundle
JS estático.

Lo offline no lo da Capacitor — ya está implementado del lado web (IndexedDB
+ los endpoints `/sync/transactions`, ver
`app/javascript/services/offline_transactions_*.js`). Capacitor aporta el
ícono en el launcher, la identidad de app propia, y el acceso a APIs nativas
(push FCM, biometría) cuando se necesiten.

## Requisitos

- Node.js y npm
- Android Studio con el SDK de Android
- JDK 21 (el que trae Android Studio sirve)

## Pasos

```bash
# 1. Dependencias (ya declaradas en package.json)
npm install

# 2. Generar el proyecto nativo (crea ./android/, no versionado)
npm run android:add

# 3. Abrir en Android Studio
npm run android:open
```

En Android Studio: **Run ▶** con un dispositivo conectado por USB (con
depuración USB activada) o un emulador. Eso instala la app directamente.

Para un APK que se pueda pasar a otro teléfono:
**Build → Generate Signed Bundle / APK → APK → Create new keystore**.

⚠️ **Guardá el keystore y su contraseña fuera del repo y con backup.** Si se
pierde, no se pueden firmar actualizaciones futuras de esa misma app en Play
Store — hay que publicar una app nueva desde cero. El `.gitignore` ya bloquea
`*.keystore` / `*.jks` para que no se suban por accidente.

## Después de cambiar `capacitor.config.json`

```bash
npm run android:sync
```

## Cambiar a qué servidor apunta

`server.url` en `capacitor.config.json` apunta a `https://finance.cd-co.com.py`.
Se usa el dominio y no una IP a propósito: sigue siendo válido después de la
migración del hosting a la notebook (ver
`wiki/decisiones/FinancePY - Hosting fase prueba (PC local)` en el vault), sin
tener que reconstruir el APK.

Para apuntar a un server local durante desarrollo, cambiar `url` a
`http://TU_IP_LOCAL:3000` y poner `"cleartext": true` (HTTP sin TLS).
**No dejar `cleartext: true` en un build que se distribuya.**

## Sin verificar todavía (hacerlo en un dispositivo real)

Estos puntos son razonamiento de arquitectura, no cosas ya probadas:

1. **Arranque en frío sin conexión.** En modo remoto el WebView pide la URL al
   abrir. La app tiene service worker con cache de navegación (del trabajo PWA
   de 2026-07-23), así que *debería* servir la versión cacheada — pero eso hay
   que confirmarlo en un teléfono real, en modo avión, cerrando la app del
   todo. Si falla, la alternativa es cambiar a modo local (empaquetar un shell
   mínimo y que el SW maneje el resto).
2. **Login.** El WebView de Capacitor tiene su propio almacén de cookies,
   aislado del Chrome del sistema — hay que iniciar sesión una vez dentro de la
   app. Es esperado, no un bug. Confirmar que la sesión sobrevive al cerrar y
   reabrir.
3. **Sync al reconectar.** Verificar con datos móviles/wifi cortados: crear un
   movimiento, reconectar, y confirmar que aparece en el server.
