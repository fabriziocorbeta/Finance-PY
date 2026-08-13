#!/usr/bin/env bash
# bin/android_link_native.sh
#
# Copia el código nativo custom (versionado en native/android/wallet-listener/)
# dentro de android/, que Capacitor regenera y por eso está gitignoreado.
# Correr después de cada `npm run android:add` o `npm run android:sync`.
set -euo pipefail

PKG_DIR="android/app/src/main/java/py/com/cdco/financespy/wallet"
MAIN_ACTIVITY="android/app/src/main/java/py/com/cdco/financespy/MainActivity.kt"

mkdir -p "$PKG_DIR"
cp native/android/wallet-listener/*.kt "$PKG_DIR/"

REGISTER_LINE="        registerPlugin(WalletListenerPlugin::class.java)"
if ! grep -qF "$REGISTER_LINE" "$MAIN_ACTIVITY"; then
  echo "⚠️  Falta registrar el plugin en $MAIN_ACTIVITY — agregá esta línea"
  echo "    dentro de onCreate(), antes de super.onCreate(savedInstanceState):"
  echo "$REGISTER_LINE"
else
  echo "✅ Plugin ya registrado en MainActivity.kt"
fi

echo ""
echo "⚠️  Verificá manualmente que android/app/src/main/AndroidManifest.xml"
echo "    tenga el bloque de native/android/wallet-listener/manifest-snippet.xml"
echo "    (el merge de manifest no se automatiza acá, ver docs/CAPACITOR.md)"

echo ""
echo "⚠️  Verificá que exista android/app/src/main/res/values/secrets.xml con el"
echo "    string resource wallet_webhook_token (no versionado, hay que crearlo a"
echo "    mano). Su valor debe coincidir con el token que espera el webhook"
echo "    android_purchase del backend Rails (ver docs/CAPACITOR.md)."
