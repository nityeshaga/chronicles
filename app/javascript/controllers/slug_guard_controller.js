import { Controller } from "@hotwired/stimulus"

// A tag's slug is its public /tag/:slug URL, so renaming it breaks inbound links. Fence
// that behind a confirm — but ONLY when the slug actually changed, so editing a tag's name
// or description stays friction-free. The field's own value at connect is the baseline.
export default class extends Controller {
  static targets = ["slug"]

  connect() {
    this.original = this.slugTarget.value
  }

  guard(event) {
    if (this.slugTarget.value === this.original) return
    if (!window.confirm("Changing this tag's slug breaks its existing /tag/ URL. Continue?")) {
      event.preventDefault()
    }
  }
}
