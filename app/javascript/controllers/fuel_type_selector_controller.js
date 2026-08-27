import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="fuel-type-selector"
export default class extends Controller {
  static targets = ["fuelType", "brandContainer", "brandSelect"];
  static values = {
    brands: {
      type: Object,
      default: {
        nafta: ["Podium", "Super 97", "Grid", "Prix"],
        diesel: ["Podium", "Euro 6", "Euro 5"]
      }
    }
  };

  connect() {
    this.updateBrands();
  }

  updateBrands() {
    if (!this.hasFuelTypeTarget || !this.hasBrandContainerTarget || !this.hasBrandSelectTarget) {
      return;
    }

    const fuelType = this.fuelTypeTarget.value;
    const allowedBrands = this.brandsValue[fuelType] || [];

    if (allowedBrands.length > 0) {
      const currentBrand = this.brandSelectTarget.value;
      const promptText = this.brandSelectTarget.dataset.prompt || "Seleccionar marca";

      // Clear existing options
      this.brandSelectTarget.innerHTML = "";

      // Add default prompt option
      const promptOption = document.createElement("option");
      promptOption.value = "";
      promptOption.textContent = promptText;
      this.brandSelectTarget.appendChild(promptOption);

      allowedBrands.forEach((brand) => {
        const option = document.createElement("option");
        option.value = brand;
        option.textContent = brand;
        if (brand === currentBrand) {
          option.selected = true;
        }
        this.brandSelectTarget.appendChild(option);
      });

      this.brandContainerTarget.classList.remove("hidden");
    } else {
      this.brandSelectTarget.value = "";
      this.brandContainerTarget.classList.add("hidden");
    }
  }
}
