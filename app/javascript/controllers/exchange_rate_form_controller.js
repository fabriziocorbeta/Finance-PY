import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "amount",
    "destinationAmount",
    "date",
    "exchangeRateContainer",
    "exchangeRateField",
    "convertDestinationDisplay",
    "calculateRateDisplay",
    "rateSourceHint"
  ];

  static values = {
    exchangeRateUrl: String,
    accountCurrencies: Object
  };

  connect() {
    this.sourceCurrency = null;
    this.destinationCurrency = null;
    this.activeTab = "convert";

    if (!this.hasRequiredExchangeRateTargets()) {
      return;
    }

    this.checkCurrencyDifference();
  }

  hasRequiredExchangeRateTargets() {
    return this.hasDateTarget;
  }

  checkCurrencyDifference() {
    const context = this.getExchangeRateContext();

    if (!context) {
      this.hideExchangeRateField();
      return;
    }

    const { fromCurrency, toCurrency, date } = context;

    if (!fromCurrency || !toCurrency) {
      this.hideExchangeRateField();
      return;
    }

    this.sourceCurrency = fromCurrency;
    this.destinationCurrency = toCurrency;

    if (fromCurrency === toCurrency) {
      this.hideExchangeRateField();
      return;
    }

    this.fetchExchangeRate(fromCurrency, toCurrency, date);
  }

  onExchangeRateTabClick(event) {
    const btn = event.target.closest("button[data-id]");
    if (!btn) {
      return;
    }

    const nextTab = btn.dataset.id;

    if (nextTab === this.activeTab) {
      return;
    }

    this.activeTab = nextTab;

    if (this.activeTab === "convert") {
      this.clearCalculateRateFields();
    } else if (this.activeTab === "calculateRate") {
      this.clearConvertFields();
    }
  }

  onAmountChange() {
    this.onAmountInputChange();
  }

  onSourceAmountChange() {
    this.onAmountInputChange();
  }

  onAmountInputChange() {
    if (!this.hasAmountTarget) {
      return;
    }

    if (this.activeTab === "convert") {
      this.calculateConvertDestination();
    } else {
      this.calculateRateFromAmounts();
    }
  }

  onConvertSourceAmountChange() {
    this.calculateConvertDestination();
  }

  onConvertExchangeRateChange() {
    this.calculateConvertDestination();
  }

  calculateConvertDestination() {
    if (!this.hasAmountTarget || !this.hasExchangeRateFieldTarget || !this.hasConvertDestinationDisplayTarget) {
      return;
    }

    const amount = Number.parseFloat(this.amountTarget.value);
    const rate = Number.parseFloat(this.exchangeRateFieldTarget.value);

    if (amount && rate && rate !== 0) {
      const destAmount = (amount * rate).toFixed(2);
      this.convertDestinationDisplayTarget.textContent = this.destinationCurrency ? `${destAmount} ${this.destinationCurrency}` : destAmount;
    } else {
      this.convertDestinationDisplayTarget.textContent = "-";
    }
  }

  onCalculateRateSourceAmountChange() {
    this.calculateRateFromAmounts();
  }

  onCalculateRateDestinationAmountChange() {
    this.calculateRateFromAmounts();
  }

  calculateRateFromAmounts() {
    if (!this.hasAmountTarget || !this.hasDestinationAmountTarget || !this.hasCalculateRateDisplayTarget || !this.hasExchangeRateFieldTarget) {
      return;
    }

    const amount = Number.parseFloat(this.amountTarget.value);
    const destAmount = Number.parseFloat(this.destinationAmountTarget.value);

    if (amount && destAmount && amount !== 0) {
      const rate = destAmount / amount;
      const formattedRate = this.formatExchangeRate(rate);
      this.calculateRateDisplayTarget.textContent = formattedRate;
      this.exchangeRateFieldTarget.value = rate.toFixed(14);
    } else {
      this.calculateRateDisplayTarget.textContent = "-";
      this.exchangeRateFieldTarget.value = "";
    }
  }

  formatExchangeRate(rate) {
    let formattedRate = rate.toFixed(14);
    formattedRate = formattedRate.replace(/(\.\d{2}\d*?)0+$/, "$1");

    return this.padMinDecimals(formattedRate);
  }

  // Pads a decimal string to at least `minDecimals` digits using plain
  // string manipulation -- never Number/toFixed, which would reintroduce
  // the binary-float rounding this feature exists to avoid.
  padMinDecimals(decimalString, minDecimals = 2) {
    const [integerPart, decimalPart = ""] = String(decimalString).split(".");
    return `${integerPart}.${decimalPart.padEnd(minDecimals, "0")}`;
  }

  clearConvertFields() {
    if (this.hasExchangeRateFieldTarget) {
      this.exchangeRateFieldTarget.value = "";
    }
    if (this.hasConvertDestinationDisplayTarget) {
      this.convertDestinationDisplayTarget.textContent = "-";
    }
    this.updateRateSourceHint(null);
  }

  clearCalculateRateFields() {
    if (this.hasDestinationAmountTarget) {
      this.destinationAmountTarget.value = "";
    }
    if (this.hasCalculateRateDisplayTarget) {
      this.calculateRateDisplayTarget.textContent = "-";
    }
    if (this.hasExchangeRateFieldTarget) {
      this.exchangeRateFieldTarget.value = "";
    }
  }

  async fetchExchangeRate(fromCurrency, toCurrency, date) {
    if (this.exchangeRateAbortController) {
      this.exchangeRateAbortController.abort();
    }

    this.exchangeRateAbortController = new AbortController();
    const signal = this.exchangeRateAbortController.signal;

    try {
      const url = new URL(this.exchangeRateUrlValue, window.location.origin);
      url.searchParams.set("from", fromCurrency);
      url.searchParams.set("to", toCurrency);
      if (date) {
        url.searchParams.set("date", date);
      }

      const response = await fetch(url, { signal });
      const data = await response.json();

      if (!this.isCurrentExchangeRateState(fromCurrency, toCurrency, date)) {
        return;
      }

      if (!response.ok) {
        if (this.shouldShowManualExchangeRate(data)) {
          this.showManualExchangeRateField(data.rate_hint);
        } else {
          this.hideExchangeRateField();
        }
        return;
      }

      if (data.same_currency) {
        this.hideExchangeRateField();
      } else {
        this.sourceCurrency = fromCurrency;
        this.destinationCurrency = toCurrency;
        this.showExchangeRateField(data.rate, data.rate_hint);
      }
    } catch (error) {
      if (error.name === "AbortError") {
        return;
      }

      console.error("Error fetching exchange rate:", error);
      this.hideExchangeRateField();
    }
  }

  showExchangeRateField(rate, hint = null) {
    if (this.hasExchangeRateFieldTarget) {
      // Pad as a string, never re-parse through a JS Number: the server
      // already sends the exact decimal digits (BigDecimal#to_s("F")), and
      // routing that through toFixed()/parseFloat() is exactly what risked
      // losing precision for rates with many significant digits (e.g. small
      // inverse rates like PYG -> USD).
      this.exchangeRateFieldTarget.value = this.padMinDecimals(rate);
    }
    if (this.hasExchangeRateContainerTarget) {
      this.exchangeRateContainerTarget.classList.remove("hidden");
    }
    this.updateRateSourceHint(hint);

    this.calculateConvertDestination();
  }

  showManualExchangeRateField(hint = null) {
    const context = this.getExchangeRateContext();
    this.sourceCurrency = context?.fromCurrency || null;
    this.destinationCurrency = context?.toCurrency || null;

    if (this.hasExchangeRateFieldTarget) {
      this.exchangeRateFieldTarget.value = "";
    }
    if (this.hasExchangeRateContainerTarget) {
      this.exchangeRateContainerTarget.classList.remove("hidden");
    }
    this.updateRateSourceHint(hint);

    this.calculateConvertDestination();
  }

  // Tells the user exactly which rate the system is about to use (and its
  // date) before they save -- e.g. the lookup can silently fall back to a
  // weekend/holiday's last available rate, which is otherwise invisible.
  updateRateSourceHint(hint) {
    if (!this.hasRateSourceHintTarget) {
      return;
    }

    if (hint) {
      this.rateSourceHintTarget.textContent = hint;
      this.rateSourceHintTarget.classList.remove("hidden");
    } else {
      this.rateSourceHintTarget.textContent = "";
      this.rateSourceHintTarget.classList.add("hidden");
    }
  }

  shouldShowManualExchangeRate(data) {
    if (!data || typeof data.error !== "string") {
      return false;
    }

    return data.error === "Exchange rate not found" || data.error === "Exchange rate unavailable";
  }

  hideExchangeRateField() {
    if (this.hasExchangeRateContainerTarget) {
      this.exchangeRateContainerTarget.classList.add("hidden");
    }
    if (this.hasExchangeRateFieldTarget) {
      this.exchangeRateFieldTarget.value = "";
    }
    if (this.hasConvertDestinationDisplayTarget) {
      this.convertDestinationDisplayTarget.textContent = "-";
    }
    if (this.hasCalculateRateDisplayTarget) {
      this.calculateRateDisplayTarget.textContent = "-";
    }
    if (this.hasDestinationAmountTarget) {
      this.destinationAmountTarget.value = "";
    }
    this.updateRateSourceHint(null);

    this.sourceCurrency = null;
    this.destinationCurrency = null;
  }

  getExchangeRateContext() {
    throw new Error("Subclasses must implement getExchangeRateContext()");
  }

  isCurrentExchangeRateState(_fromCurrency, _toCurrency, _date) {
    throw new Error("Subclasses must implement isCurrentExchangeRateState()");
  }
}
