import { Controller } from "@hotwired/stimulus"

// The writing index's tabs and filter box. Every row is rendered once and always present
// in the DOM (so it stays greppable / test-reachable); a tab and a query only decide
// which rows show, and in what order. State lives on the DOM — the pressed tab, the text
// in the field, and each row's data-status / data-search / data-edited / data-goes-live
// — never in JS, and the sort keys are stamped by the server so this never re-derives a
// fact it was handed.
export default class extends Controller {
  static targets = ["tab", "row", "empty", "query", "list"]

  connect() {
    if (this.hasEmptyTarget) this.blankMessage = this.emptyTarget.textContent
    // A phone must not pop its keyboard on load; at a desk the writer can start typing
    // the title he came for the moment the page paints.
    if (this.hasQueryTarget && window.matchMedia("(min-width: 600px)").matches) this.queryTarget.focus()
  }

  select(event) {
    this.tabTargets.forEach((tab) => {
      const active = tab === event.currentTarget
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active)
    })

    this.filter()
  }

  clear() {
    this.queryTarget.value = ""
    this.filter()
  }

  filter() {
    const tab = this.activeTab
    const words = this.query.toLowerCase().split(/\s+/).filter(Boolean)

    const shown = this.rowTargets.filter((row) => {
      const match = (tab.dataset.status === "all" || row.dataset.status === tab.dataset.status) &&
        words.every((word) => row.dataset.search.includes(word))
      row.hidden = !match
      return match
    })

    this.reorder(shown, tab.dataset.status)
    this.report(shown.length, tab.dataset.label)
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

  report(shown, label) {
    if (!this.hasEmptyTarget) return

    this.emptyTarget.textContent = this.query ? `Nothing matches "${this.query}" in ${label}.` : this.blankMessage
    this.emptyTarget.hidden = shown > 0
  }

  get activeTab() {
    return this.tabTargets.find((tab) => tab.classList.contains("is-active"))
  }

  get query() {
    return this.hasQueryTarget ? this.queryTarget.value.trim() : ""
  }
}
