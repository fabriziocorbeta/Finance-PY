import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["form", "input", "mic", "results"];
  static values = { url: String };

  _timer = null;

  connect() {
    this._outsideClick = (e) => {
      if (!this.element.contains(e.target)) {
        this.resultsTarget.classList.add("hidden");
      }
    };
    document.addEventListener("click", this._outsideClick);
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer);
    if (this._outsideClick) document.removeEventListener("click", this._outsideClick);
  }

  onInput() {
    const query = this.inputTarget.value.trim();
    if (this._timer) clearTimeout(this._timer);
    if (query.length < 1) {
      this.resultsTarget.classList.add("hidden");
      return;
    }
    this._timer = setTimeout(() => this._search(query), 280);
  }

  selectResult(event) {
    const btn = event.currentTarget;
    const ticker = btn.dataset.ticker;
    const mic = btn.dataset.mic || "";
    if (!ticker) return;

    this.inputTarget.value = ticker;
    if (this.hasMicTarget) this.micTarget.value = mic;
    this.resultsTarget.classList.add("hidden");
    this.formTarget.requestSubmit();
  }

  async _search(query) {
    try {
      const resp = await fetch(`${this.urlValue}?ticker=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
      });
      if (!resp.ok) return;
      const data = await resp.json();
      const items = data.results || [];

      if (items.length === 0) {
        this.resultsTarget.classList.add("hidden");
        return;
      }

      this.resultsTarget.innerHTML = items
        .map((item) => {
          const priceHtml =
            item.current_price != null
              ? `<span class="text-xs font-semibold text-primary tabular-nums">${Number(item.current_price).toFixed(2)} ${item.currency || "USD"}</span>`
              : "";
          const pct = item.change_percent != null ? Number(item.change_percent) : null;
          const pctHtml =
            pct != null
              ? `<span class="text-[11px] font-medium tabular-nums ${pct >= 0 ? "text-green-600" : "text-red-600"}">${pct >= 0 ? "+" : ""}${pct.toFixed(2)}%</span>`
              : "";
          const micBadge = item.exchange_operating_mic
            ? `<span class="text-[10px] px-1.5 py-0.5 rounded bg-container-inset text-secondary">${this._escape(item.exchange_operating_mic)}</span>`
            : "";

          return `
            <button type="button"
                    data-action="click->watchlist-search#selectResult"
                    data-ticker="${this._escape(item.ticker)}"
                    data-mic="${this._escape(item.exchange_operating_mic || "")}"
                    class="w-full px-3.5 py-2.5 text-left hover:bg-surface-hover flex items-center justify-between gap-3 transition-colors cursor-pointer">
              <div class="min-w-0">
                <div class="flex items-center gap-1.5">
                  <span class="text-sm font-semibold text-primary font-mono">${this._escape(item.ticker)}</span>
                  ${micBadge}
                </div>
                <p class="text-xs text-secondary truncate">${this._escape(item.name || item.ticker)}</p>
              </div>
              <div class="text-right shrink-0 flex flex-col items-end">
                ${priceHtml}
                ${pctHtml}
              </div>
            </button>
          `;
        })
        .join("");

      this.resultsTarget.classList.remove("hidden");
    } catch (_) {
      // Ignore transient lookup errors
    }
  }

  _escape(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }
}
