import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="sidebar-active-account"
// Highlights the currently active account link in the sidebar and opens its parent <details> disclosure
export default class extends Controller {
  connect() {
    this.highlightActiveAccount();
  }

  highlightActiveAccount() {
    const currentPath = window.location.pathname;

    const links = this.element.querySelectorAll("a[href]");

    links.forEach((link) => {
      const href = link.getAttribute("href");
      if (!href || !href.startsWith("/accounts/")) return;

      const isMatch = href === currentPath;

      if (isMatch) {
        link.classList.add("bg-container");
        link.classList.remove("hover:bg-surface-hover");

        const details = link.closest("details");
        if (details) {
          details.open = true;
        }
      } else {
        link.classList.remove("bg-container");
        link.classList.add("hover:bg-surface-hover");
      }
    });
  }
}
