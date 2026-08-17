import { Controller } from "@hotwired/stimulus"

// The writing index's filter tabs. Every row is rendered once and always present in the
// DOM (so it stays greppable / test-reachable); a tab only decides which rows show, and
// in what order. State lives on the DOM — the pressed tab and each row's data-status /
// data-edited / data-goes-live — never in JS, and the sort keys are stamped by the
// server so this never re-derives a fact it was handed.
export default class extends Controller {
  static targets = ["tab", "row", "empty", "list"]

  select(event) {
    this.tabTargets.forEach((tab) => {
      const active = tab === event.currentTarget
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active)
    })

    this.filter()
  }

  filter() {
    const status = this.activeTab.dataset.status

    const shown = this.rowTargets.filter((row) => {
      const match = status === "all" || row.dataset.status === status
      row.hidden = !match
      return match
    })

    this.reorder(shown, status)
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown.length > 0
  }

  // Scheduled answers "what goes live next", so reading down it is reading forward in
  // time; every other tab reads back from what was touched last, which is the order the
  // server already sent, so nothing visibly moves.
  reorder(rows, status) {
    if (!this.hasListTarget) return

    const scheduled = status === "scheduled"
    const key = scheduled ? "goesLive" : "edited"
    const direction = scheduled ? 1 : -1

    rows
      .slice()
      .sort((a, b) => direction * a.dataset[key].localeCompare(b.dataset[key]))
      .forEach((row) => this.listTarget.appendChild(row))
  }

  get activeTab() {
    return this.tabTargets.find((tab) => tab.classList.contains("is-active"))
  }
}
