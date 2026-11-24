import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["ticker", "price", "banner", "name", "livePrice", "change"];
  static values = { url: String };

  _timer = null;
  _priceManuallyEdited = false;

  connect() {
    if (this.hasPriceTarget && this.priceTarget.value.trim() !== "") {
      this._priceManuallyEdited = false;
    }
    if (this.hasTickerTarget && this.tickerTarget.value.trim() !== "") {
      this._lookup(this.tickerTarget.value.trim());
    }
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer);
  }

  onTickerInput() {
    const query = this.tickerTarget.value.trim();
    this._priceManuallyEdited = false;
    if (this._timer) clearTimeout(this._timer);
    if (query.length < 1) {
      this.bannerTarget.classList.add("hidden");
      return;
    }
    this._timer = setTimeout(() => this._lookup(query), 400);
  }

  onPriceInput() {
    this._priceManuallyEdited = true;
  }

  useCurrentPrice() {
    const current = this.priceTarget.dataset.livePrice;
    if (current) {
      this.priceTarget.value = current;
      this._priceManuallyEdited = false;
    }
  }

  async _lookup(ticker) {
    try {
      const resp = await fetch(`${this.urlValue}?ticker=${encodeURIComponent(ticker)}`, {
        headers: { Accept: "application/json" },
      });
      if (!resp.ok) return;
      const data = await resp.json();

      if (!data.found || data.current_price == null) {
        this.bannerTarget.classList.add("hidden");
        return;
      }

      this.nameTarget.textContent = `${data.ticker} · ${data.name}`;
      this.livePriceTarget.textContent = `${Number(data.current_price).toFixed(2)} ${data.currency || "USD"}`;

      if (data.change_percent != null) {
        const pct = Number(data.change_percent);
        this.changeTarget.textContent = `(${pct >= 0 ? "+" : ""}${pct.toFixed(2)}%)`;
        this.changeTarget.className = `text-xs font-medium ${pct >= 0 ? "text-green-600" : "text-red-600"}`;
      } else {
        this.changeTarget.textContent = "";
      }

      this.priceTarget.dataset.livePrice = Number(data.current_price).toFixed(2);
      if (!this._priceManuallyEdited || this.priceTarget.value.trim() === "") {
        this.priceTarget.value = Number(data.current_price).toFixed(2);
      }

      this.bannerTarget.classList.remove("hidden");
    } catch (_) {
      // Ignore transient network errors
    }
  }
}
