import { Controller } from "@hotwired/stimulus"

// Wires interactivity for imported Koenig cards in rich-text bodies.
// The markup ships inside Action Text, so behavior is delegated here rather
// than via per-element data-actions. State lives on the element itself.
export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.onClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
  }

  onClick = (event) => {
    const toggle = event.target.closest(".kg-toggle-card")
    if (!toggle || !event.target.closest(".kg-toggle-heading")) return
    const open = toggle.getAttribute("data-kg-toggle-state") === "open"
    toggle.setAttribute("data-kg-toggle-state", open ? "close" : "open")
  }
}
