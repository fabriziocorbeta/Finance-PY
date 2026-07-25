import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="auto-submit"
// Submits the closest form on an event (e.g. change on a file input) without
// an inline onchange="" attribute, which CSP enforce blocks (nonces only
// cover <script> tags, not inline event handler attributes).
export default class extends Controller {
  submit() {
    this.element.closest("form").requestSubmit();
  }
}
