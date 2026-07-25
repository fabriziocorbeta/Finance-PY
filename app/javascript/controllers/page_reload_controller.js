import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="page-reload"
export default class extends Controller {
  reload() {
    window.location.reload();
  }
}
