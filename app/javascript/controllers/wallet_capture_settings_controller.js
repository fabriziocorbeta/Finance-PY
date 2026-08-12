import { Controller } from "@hotwired/stimulus";
import {
  isWalletListenerAvailable,
  isWalletListenerEnabled,
  requestWalletListenerPermission,
  getPendingWalletCaptureCount,
  retryPendingWalletCaptures,
} from "services/wallet_listener";

// Connects to data-controller="wallet-capture-settings"
//
// Solo Android/Capacitor: en web (o iOS) el plugin no existe y el estado
// queda fijo en "Disponible solo en la app Android.".
export default class extends Controller {
  static targets = ["status"];

  async connect() {
    this.boundOnline = () => this.retryPending();
    window.addEventListener("online", this.boundOnline);
    await this.refresh();
  }

  disconnect() {
    window.removeEventListener("online", this.boundOnline);
  }

  async refresh() {
    if (!isWalletListenerAvailable()) {
      this.statusTarget.textContent = "Disponible solo en la app Android.";
      return;
    }

    try {
      const enabled = await isWalletListenerEnabled();

      // Flushea capturas pendientes acá también (no solo en el evento "online"
      // en vivo), para cubrir el caso común de "se abrió la app ya reconectada
      // con backlog pendiente" — en connect() y en cada refresh subsiguiente.
      if (enabled && navigator.onLine) {
        await retryPendingWalletCaptures();
      }

      const pending = await getPendingWalletCaptureCount();

      this.statusTarget.textContent = enabled
        ? `Activado. ${pending} captura(s) pendiente(s) de sincronizar.`
        : "Desactivado — activá el acceso a notificaciones para capturar compras de Wallet automáticamente.";
    } catch (error) {
      // Falla del plugin nativo: no dejar el UI colgado en "Verificando estado...".
      console.warn("[wallet] refresh failed", error);
      this.statusTarget.textContent = "No se pudo verificar el estado. Intentá de nuevo más tarde.";
    }
  }

  async requestPermission() {
    await requestWalletListenerPermission();
    await this.refresh();
  }

  // Se dispara al recuperar conectividad (evento "online" del navegador
  // embebido en la WebView de Capacitor). Empuja la cola nativa de capturas
  // pendientes y refresca el contador mostrado.
  async retryPending() {
    if (!isWalletListenerAvailable()) return;

    const enabled = await isWalletListenerEnabled();
    if (!enabled) return;

    await retryPendingWalletCaptures();
    await this.refresh();
  }
}
