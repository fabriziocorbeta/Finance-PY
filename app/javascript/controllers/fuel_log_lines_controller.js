import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="fuel-log-lines"
export default class extends Controller {
  static targets = ["container", "template"]

  add() {
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }
}
