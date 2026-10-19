# Captura de compras desde notificaciones (Android)

Cómo una compra con Google Pay o una notificación bancaria termina siendo una
transacción en FinancePY, y los dos modos de falla que ya nos costaron plata.

## El camino

1. `WalletNotificationListenerService` recibe la notificación. Descarta todo
   paquete que no esté en `BankNotificationExtractors.watchedPackages`.
2. `BankNotificationExtractors.forPackage()` elige el extractor. Google Pay es
   `com.google.android.apps.walletnfcrel` → `WalletTapExtractor`.
3. El extractor saca monto, texto de tarjeta y comercio del título y el cuerpo.
   Para Google Pay el **título es el comercio** y el cuerpo es
   `PYG<monto> con <tarjeta>`.
4. `AccountMapping.accountIdFor()` traduce el texto de tarjeta a una cuenta.
5. `WebhookClient` postea a `POST /api/v1/android_purchases`.
6. `AndroidPurchase::WebhookProcessor` crea el `Entry` + `Transaction`, con
   `external_id = SHA256("monto|timestamp|comercio")` para idempotencia.

## Modo de falla 1: el mapeo va contra el NOMBRE de la cuenta

`AccountMapping` compara el texto de la tarjeta contra el **nombre** de la
cuenta, por substring en las dos direcciones:

```kotlin
cardText.contains(account.name, true) || account.name.contains(cardText, true)
```

**Renombrar una cuenta rompe la captura.** Pasó de verdad el 2026-10-18: la
cuenta se renombró el 12/10 de algo que contenía `Amex Gold` a `"Amex - Glod "`
(con typo y espacio al final), y a partir de ahí `"Amex Gold ••2269"` dejó de
matchear. Tres compras del 18/10 no entraron. Las del 30/09, 10/10 y 11/10, con
la misma tarjeta, sí habían entrado.

**Si una captura deja de llegar, lo primero a mirar es si el nombre de la cuenta
cambió.** Comparar contra el texto exacto de la notificación:

```bash
adb shell dumpsys notification --noredact | grep -A14 walletnfcrel | grep "android.te\?xt\|android.title"
```

Arreglo de fondo pendiente: guardar un identificador de tarjeta (`••2269`) en la
cuenta y matchear por eso, no por el nombre. Requiere campo nuevo + UI en web,
Android e iOS.

## Modo de falla 2: se descartaba en silencio (ARREGLADO)

Hasta el 2026-10-18, si `accountIdFor()` devolvía null, `WalletCaptureHandler`
hacía `return@forEach` y la compra **se perdía**: no se guardaba en disco, no
quedaba registro, no avisaba. El caso `token_missing`, dos líneas más abajo, sí
la encolaba.

Ahora `PendingCapture.accountId` es nullable y la captura sin cuenta **se encola
igual**. `retryPending()` —que corre al abrir la app— reintenta **el mapeo**,
no solo el POST, así que la compra entra sola en cuanto alguna cuenta vuelve a
matchear. Nunca se descarta.

El formato en disco es compatible hacia atrás: `accountId` se omite cuando es
null, y `parseCaptureJson` usa `has()`/`isNull()` en vez de `getString()`, así
que lo encolado por builds viejas sigue parseando.

## Backfill manual

Si hay que cargar capturas perdidas, usar el mismo `WebhookProcessor` —no
insertar `Entry` a mano— así quedan con la misma forma, categorización e
idempotencia que una captura real. `accounts` y `entries` tienen RLS, y un
`rails runner` no tiene contexto de familia, así que va envuelto:

```ruby
RlsContext.with_auth_bypass(reason: "manual_gpay_backfill") do
  account = Account.find_by(id: ACCOUNT_ID)
  AndroidPurchase::WebhookProcessor.new(params, family: account.family, user: nil).process
end
```

El monto va **sin separadores** (`"37970"`, no `"37,970"`) y el timestamp en
ISO con offset (`"2026-10-18T17:37:16-03:00"`). Repetir el mismo backfill es
seguro: el `external_id` lo vuelve idempotente y devuelve `:duplicate`.

## Categorización de combustible

`FUEL_MERCHANT_KEYWORDS` en `AndroidPurchase::WebhookProcessor` es una lista de
marcas confirmadas contra capturas reales, no exhaustiva. Solo aplica a familias
que tengan al menos un `FleetVehicle`. Se extiende a medida que aparecen marcas
nuevas en notificaciones reales.
