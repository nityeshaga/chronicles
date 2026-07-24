import { Controller } from "@hotwired/stimulus"

// The editor's two overlays: the "Post settings" slide-over (slug, tags, metadata) and
// the "Publish" popover. Only one is open at a time; a shared backdrop, the Escape key,
// and clicking an open toggle again all close whatever's showing. State is a single class
// on each element — no JS bookkeeping beyond "which one, if any." The panels stay in the
// DOM (and stay reachable to non-JS test drivers); this only toggles their visibility.
export default class extends Controller {
  static targets = ["settings", "publish", "backdrop"]
  static classes = ["open"]

  toggleSettings(event) {
    event.preventDefault()
    this.#show(this.settingsTarget.classList.contains(this.openClass) ? null : this.settingsTarget)
  }

  togglePublish(event) {
    event.preventDefault()
    this.#show(this.publishTarget.classList.contains(this.openClass) ? null : this.publishTarget)
  }

  close() {
    this.#show(null)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  #show(panel) {
    for (const target of this.#panels) {
      target.classList.toggle(this.openClass, target === panel)
    }
    this.backdropTarget.classList.toggle(this.openClass, panel !== null)
  }

  get #panels() {
    return [this.settingsTarget, this.hasPublishTarget ? this.publishTarget : null].filter(Boolean)
  }
}
