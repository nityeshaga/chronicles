import { Controller } from "@hotwired/stimulus"

// A submit button whose label depends on whether one field has been filled in. Both
// labels ride in as values, so this knows nothing about what is being submitted — it
// swaps a string when the field goes from empty to filled and back.
export default class extends Controller {
  static targets = ["field", "submit"]
  static values = { empty: String, filled: String }

  // On connect too: a page restored from the Turbo cache or the browser's back button
  // hands back a field the server rendered the label for while it was still empty.
  connect() {
    this.change()
  }

  change() {
    this.submitTarget.value = this.fieldTarget.value ? this.filledValue : this.emptyValue
  }
}
