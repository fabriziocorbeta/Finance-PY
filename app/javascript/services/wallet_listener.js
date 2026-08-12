// Puente al plugin nativo Capacitor "WalletListener" (native/android/wallet-listener/).
// Solo UI: permiso y estado. La captura, extracción, mapeo y POST al webhook
// pasan enteramente por Kotlin nativo — ver Global Constraints del plan de
// implementación (docs/superpowers/plans/2026-08-12-financespy-mobile-unificacion-capacitor.md)
// sobre por qué el token del webhook no puede tocar este bundle.

function plugin() {
  return window.Capacitor?.Plugins?.WalletListener ?? null;
}

export function isWalletListenerAvailable() {
  return !!plugin();
}

export async function isWalletListenerEnabled() {
  const p = plugin();
  if (!p) return false;
  const { enabled } = await p.isListenerEnabled();
  return enabled;
}

export async function requestWalletListenerPermission() {
  const p = plugin();
  if (!p) return;
  await p.requestPermission();
}

export async function getPendingWalletCaptureCount() {
  const p = plugin();
  if (!p) return 0;
  const { count } = await p.pendingCount();
  return count;
}

export async function retryPendingWalletCaptures() {
  const p = plugin();
  if (!p) return 0;
  const { applied } = await p.retryPending();
  return applied;
}

export function onWalletCapture(handler) {
  const p = plugin();
  if (!p) return () => {};
  const listenerPromise = p.addListener("walletCapture", handler);
  return () => listenerPromise.then((l) => l.remove());
}
