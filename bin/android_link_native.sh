#!/usr/bin/env bash
# bin/android_link_native.sh
#
# Copia el código nativo custom (versionado en native/android/wallet-listener/)
# dentro de android/, que Capacitor regenera y por eso está gitignoreado.
# Correr después de cada `npm run android:add` o `npm run android:sync`,
# y como paso previo a cualquier `./gradlew assembleDebug` si hay dudas de
# que android/ se haya regenerado. Es idempotente: correrlo de nuevo sobre
# un proyecto ya parchado no rompe nada.
set -euo pipefail

PKG_DIR="android/app/src/main/java/py/com/cdco/financespy/wallet"
MAIN_ACTIVITY="android/app/src/main/java/py/com/cdco/financespy/MainActivity.java"
MANIFEST="android/app/src/main/AndroidManifest.xml"
MANIFEST_SNIPPET="native/android/wallet-listener/manifest-snippet.xml"
ROOT_GRADLE="android/build.gradle"
APP_GRADLE="android/app/build.gradle"

mkdir -p "$PKG_DIR"
cp native/android/wallet-listener/*.kt "$PKG_DIR/"
echo "✅ Kotlin nativo copiado a $PKG_DIR"

# --- Plugin de Kotlin en Gradle (auto-fix) ---
# El proyecto lo genera Capacitor como Java-only; sin esto, compileDebugJavaWithJavac
# no ve ninguna clase Kotlin y el build falla con "cannot find symbol".
if grep -qF "kotlin_version" "$ROOT_GRADLE" 2>/dev/null; then
  echo "✅ Kotlin ya configurado en $ROOT_GRADLE"
else
  python3 - "$ROOT_GRADLE" << 'PY_EOF'
import sys
path = sys.argv[1]
content = open(path).read()
content = content.replace(
    "buildscript {\n    \n    repositories {",
    'buildscript {\n    ext.kotlin_version = "2.0.21"\n\n    repositories {'
)
content = content.replace(
    "classpath 'com.google.gms:google-services:4.4.4'",
    "classpath 'com.google.gms:google-services:4.4.4'\n        classpath \"org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version\""
)
open(path, "w").write(content)
PY_EOF
  echo "✅ Kotlin plugin classpath agregado a $ROOT_GRADLE (auto-fix aplicado)"
fi

if grep -qF "kotlin-android" "$APP_GRADLE" 2>/dev/null; then
  echo "✅ Plugin kotlin-android ya aplicado en $APP_GRADLE"
else
  sed -i.bak "s/apply plugin: 'com.android.application'/apply plugin: 'com.android.application'\napply plugin: 'kotlin-android'/" "$APP_GRADLE"
  rm -f "$APP_GRADLE.bak"
  echo "✅ Plugin kotlin-android aplicado en $APP_GRADLE (auto-fix aplicado)"
fi

# --- MainActivity.java: registrar el plugin (auto-fix) ---
if grep -qF "registerPlugin(WalletListenerPlugin.class)" "$MAIN_ACTIVITY" 2>/dev/null; then
  echo "✅ Plugin ya registrado en $MAIN_ACTIVITY"
else
  cat > "$MAIN_ACTIVITY" << 'JAVA_EOF'
package py.com.cdco.financespy;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;
import py.com.cdco.financespy.wallet.WalletListenerPlugin;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(WalletListenerPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
JAVA_EOF
  echo "✅ Plugin registrado en $MAIN_ACTIVITY (auto-fix aplicado)"
fi

# --- AndroidManifest.xml: inyectar el <service> si falta (auto-fix) ---
if grep -qF "WalletNotificationListenerService" "$MANIFEST" 2>/dev/null; then
  echo "✅ Service ya declarado en $MANIFEST"
else
  SNIPPET_BODY=$(grep -v '^<!--' "$MANIFEST_SNIPPET")
  python3 - "$MANIFEST" "$SNIPPET_BODY" << 'PY_EOF'
import sys
manifest_path, snippet = sys.argv[1], sys.argv[2]
with open(manifest_path) as f:
    content = f.read()
marker = "</application>"
idx = content.rindex(marker)
content = content[:idx] + snippet + "\n\n    " + content[idx:]
with open(manifest_path, "w") as f:
    f.write(content)
PY_EOF
  echo "✅ Service inyectado en $MANIFEST (auto-fix aplicado)"
fi

# --- secrets.xml: no se automatiza (secreto, no versionado) ---
SECRETS="android/app/src/main/res/values/secrets.xml"
if [ -f "$SECRETS" ] && grep -qF "wallet_webhook_token" "$SECRETS"; then
  echo "✅ secrets.xml presente con wallet_webhook_token"
else
  echo "⚠️  Falta $SECRETS con el string resource wallet_webhook_token."
  echo "    Su valor debe coincidir con ANDROID_WEBHOOK_TOKEN del backend (.env.local)."
  echo "    Este archivo NO se versiona ni se auto-genera acá a propósito (secreto)."
fi
