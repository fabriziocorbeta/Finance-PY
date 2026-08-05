import { Controller } from "@hotwired/stimulus";
import {
  getCachedTransactions,
  getAccounts,
  queueWrite,
  cacheDocuments,
} from "services/offline_transactions_db";
import { syncNow } from "services/offline_transactions_sync";

// Connects to data-controller="offline-transactions"
//
// Online: deja la vista server-rendered intacta y dispara una sincronización.
// Offline: la reemplaza por la lista cacheada localmente + un form de alta.
export default class extends Controller {
  static targets = ["onlineContent", "offlineContent", "list", "accountSelect", "form"];

  connect() {
    this.boundRefresh = () => this.refresh();
    window.addEventListener("online", this.boundRefresh);
    window.addEventListener("offline", this.boundRefresh);
    this.refresh();
  }

  disconnect() {
    window.removeEventListener("online", this.boundRefresh);
    window.removeEventListener("offline", this.boundRefresh);
  }

  async refresh() {
    if (navigator.onLine) {
      this.onlineContentTarget.classList.remove("hidden");
      this.offlineContentTarget.classList.add("hidden");

      try {
        await syncNow();
      } catch (error) {
        // Sin conexión real o server caído: la app sigue usable con lo cacheado.
        console.warn("[offline] sync failed", error);
      }
      return;
    }

    this.onlineContentTarget.classList.add("hidden");
    this.offlineContentTarget.classList.remove("hidden");

    await this.renderAccounts();
    await this.renderList();
  }

  async renderAccounts() {
    const accounts = await getAccounts();

    this.accountSelectTarget.innerHTML = accounts
      .map(
        (account) =>
          `<option value="${this.escape(account.id)}" data-currency="${this.escape(account.currency)}">${this.escape(account.name)}</option>`
      )
      .join("");
  }

  async renderList() {
    const docs = await getCachedTransactions(100);

    if (!docs.length) {
      this.listTarget.innerHTML =
        '<p class="text-sm text-secondary py-4">No hay movimientos guardados en este dispositivo todavía.</p>';
      return;
    }

    this.listTarget.innerHTML = docs.map((doc) => this.rowHtml(doc)).join("");
  }

  rowHtml(doc) {
    const amount = Number.parseFloat(doc.amount);
    // Misma convención que TransactionsController#entry_params:
    // inflow se guarda negativo, outflow positivo.
    const isInflow = amount < 0;
    const sign = isInflow ? "+" : "-";
    const amountClass = isInflow ? "text-green-600" : "text-primary";
    const pendingBadge = doc.__pending
      ? '<span class="text-xs bg-yellow-100 text-yellow-800 rounded px-1.5 py-0.5 ml-2">pendiente</span>'
      : "";

    return `<div class="flex justify-between items-center py-2 border-b border-secondary">
      <div>
        <div class="font-medium text-primary">${this.escape(doc.name)}${pendingBadge}</div>
        <div class="text-sm text-secondary">${this.escape(doc.date)}</div>
      </div>
      <div class="font-mono ${amountClass}">${sign}${Math.abs(amount).toFixed(2)} ${this.escape(doc.currency)}</div>
    </div>`;
  }

  async submitOffline(event) {
    event.preventDefault();

    const form = this.formTarget;
    const selectedOption = this.accountSelectTarget.selectedOptions[0];
    if (!selectedOption) return;

    const rawAmount = Number.parseFloat(form.querySelector('[name="amount"]').value || "0");
    const nature = form.querySelector('[name="nature"]').value;
    const signedAmount = nature === "inflow" ? -Math.abs(rawAmount) : Math.abs(rawAmount);

    const doc = {
      id: crypto.randomUUID(),
      account_id: selectedOption.value,
      name: form.querySelector('[name="name"]').value,
      date: form.querySelector('[name="date"]').value,
      amount: signedAmount.toString(),
      currency: selectedOption.dataset.currency,
      notes: null,
    };

    await queueWrite(doc);
    // También al cache, para que aparezca en la lista sin esperar a sincronizar.
    await cacheDocuments([
      { ...doc, __pending: true, updated_at: new Date().toISOString() },
    ]);

    form.reset();
    await this.renderList();
  }

  escape(value) {
    const div = document.createElement("div");
    div.textContent = value == null ? "" : String(value);
    return div.innerHTML;
  }
}
