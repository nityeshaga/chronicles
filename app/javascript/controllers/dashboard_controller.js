import { Controller } from "@hotwired/stimulus"

// The writing index's filter tabs. Every row is rendered once and always present in the
// DOM (so it stays greppable / test-reachable); a tab just toggles which statuses show.
// "all" shows everything. State lives on the DOM — the pressed tab and each row's
// data-status — not in JS.
export default class extends Controller {
  static targets = ["tab", "row", "empty"]

  filter(event) {
    const status = event.currentTarget.dataset.status

    this.tabTargets.forEach((tab) => {
      const active = tab === event.currentTarget
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active)
    })

    let shown = 0
    this.rowTargets.forEach((row) => {
      const match = status === "all" || row.dataset.status === status
      row.hidden = !match
      if (match) shown++
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
  }
}
