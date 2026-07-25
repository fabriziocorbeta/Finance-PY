import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="stop-propagation"
export default class extends Controller {
  stop(event) {
    event.stopPropagation();
  }
}
