import { Controller } from "@hotwired/stimulus";
import { getPendingSales, deletePendingSale, markNeedsReview } from "services/offline_sales_db";

// Connects to data-controller="pending-sales"
export default class extends Controller {
  static targets = ["container", "list"];

  connect() {
    this.render();
    this.listTarget.addEventListener("click", this.handleRetryClick.bind(this));
  }

  async render() {
    const pending = await getPendingSales();

    if (pending.length === 0) {
      this.containerTarget.classList.add("hidden");
      this.listTarget.replaceChildren();
      return;
    }

    this.containerTarget.classList.remove("hidden");
    this.listTarget.replaceChildren(...pending.map((sale) => this.buildRow(sale)));
  }

  buildRow(sale) {
    const clientEntry = sale.formData.find(([key]) => key === "sale[client_name]");
    const clientName = clientEntry ? clientEntry[1] : "-";
    const needsReview = sale.status === "needs_review";
    const statusLabel = needsReview ? (sale.errorMessage || "Necesita revisión") : "Pendiente de sincronizar";
    const statusClass = needsReview ? "bg-red-100 text-red-800" : "bg-gray-100 text-gray-800";

    const row = document.createElement("div");
    row.className = "flex items-center justify-between px-4 py-3 border-b border-gray-100";

    const clientSpan = document.createElement("span");
    clientSpan.className = "text-sm text-primary";
    clientSpan.textContent = clientName;

    const actionsSpan = document.createElement("span");
    actionsSpan.className = "flex items-center";

    const statusBadge = document.createElement("span");
    statusBadge.className = `inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${statusClass}`;
    statusBadge.textContent = statusLabel;
    actionsSpan.appendChild(statusBadge);

    if (needsReview) {
      const retryButton = document.createElement("button");
      retryButton.type = "button";
      retryButton.dataset.retryId = String(sale.id);
      retryButton.className = "text-xs font-medium text-primary underline ml-2";
      retryButton.textContent = "Reintentar";
      actionsSpan.appendChild(retryButton);
    }

    row.append(clientSpan, actionsSpan);
    return row;
  }

  async handleRetryClick(event) {
    const button = event.target.closest("[data-retry-id]");
    if (!button || button.disabled) return;

    const id = Number(button.dataset.retryId);
    button.disabled = true;

    const pending = await getPendingSales();
    const sale = pending.find((s) => s.id === id);
    if (!sale) return;

    const body = new FormData();
    sale.formData.forEach(([key, value]) => body.append(key, value));

    try {
      const response = await fetch("/sales", {
        method: "POST",
        body,
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      });

      if (response.ok) {
        await deletePendingSale(id);
      } else {
        const data = await response.json().catch(() => ({}));
        const message = data.errors?.join(", ") || "Falló el reintento manual";
        await markNeedsReview(id, message);
      }
    } catch (error) {
      await markNeedsReview(id, "Sin conexión — probá de nuevo");
    }

    this.render();
  }
}
