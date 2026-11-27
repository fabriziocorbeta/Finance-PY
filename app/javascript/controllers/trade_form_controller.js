import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="trade-form"
export default class extends Controller {
  static targets = ["qty", "price", "fee", "amount"];
  static values = { type: { type: String, default: "buy" } };

  // Reloads the page with a new type without closing the modal
  async changeType(event) {
    const url = new URL(event.params.url, window.location.origin);
    url.searchParams.set(event.params.key, event.target.value);
    Turbo.visit(url, { frame: "modal" });
  }

  onQtyOrPriceInput() {
    if (!this.hasAmountTarget) return;

    const qty = this._num(this.qtyTarget);
    const price = this._num(this.priceTarget);
    const fee = this.hasFeeTarget ? Math.max(0, this._num(this.feeTarget) || 0) : 0;
    const amount = this._num(this.amountTarget);

    if (qty > 0 && price > 0) {
      const total = this.typeValue === "sell" ? Math.max(0, qty * price - fee) : qty * price + fee;
      this.amountTarget.value = this._formatDecimal(total, 2);
    } else if (amount > 0 && qty > 0 && !(price > 0)) {
      const principal = this._principal(amount, fee);
      this.priceTarget.value = this._formatDecimal(principal / qty, 6);
    } else if (amount > 0 && price > 0 && !(qty > 0)) {
      const principal = this._principal(amount, fee);
      this.qtyTarget.value = this._formatDecimal(principal / price, 8);
    }
  }

  onAmountInput() {
    if (!this.hasAmountTarget) return;

    const amount = this._num(this.amountTarget);
    if (!(amount > 0)) return;

    const fee = this.hasFeeTarget ? Math.max(0, this._num(this.feeTarget) || 0) : 0;
    const principal = this._principal(amount, fee);
    const price = this.hasPriceTarget ? this._num(this.priceTarget) : 0;
    const qty = this.hasQtyTarget ? this._num(this.qtyTarget) : 0;

    if (price > 0) {
      this.qtyTarget.value = this._formatDecimal(principal / price, 8);
    } else if (qty > 0) {
      this.priceTarget.value = this._formatDecimal(principal / qty, 6);
    }
  }

  onFeeInput() {
    if (!this.hasAmountTarget) return;

    const qty = this.hasQtyTarget ? this._num(this.qtyTarget) : 0;
    const price = this.hasPriceTarget ? this._num(this.priceTarget) : 0;

    if (qty > 0 && price > 0) {
      this.onQtyOrPriceInput();
    } else {
      this.onAmountInput();
    }
  }

  _principal(amount, fee) {
    return this.typeValue === "sell" ? amount + fee : Math.max(0, amount - fee);
  }

  _num(el) {
    const val = Number.parseFloat(el?.value);
    return Number.isFinite(val) ? val : 0;
  }

  _formatDecimal(value, maxDecimals) {
    if (!Number.isFinite(value) || value < 0) return "";
    return Number(value.toFixed(maxDecimals)).toString();
  }
}
