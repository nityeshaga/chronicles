import { Controller } from "@hotwired/stimulus"

// The writing index's tabs and filter box. Every row is rendered once and always present
// in the DOM (so it stays greppable / test-reachable); a tab and a query only decide
// which rows show, and in what order. State lives on the DOM and nowhere else — which tab
// is pressed, the text in the field, each row's data-status / data-search, and the two
// sort keys the server stamped on it. The axis and direction ride on the pressed tab too,
// so this file sorts what it is told to sort and knows no tab by name.
export default class extends Controller {
  static targets = ["tab", "row", "empty", "query", "list"]

  connect() {
    // A phone must not pop its keyboard on load; at a desk the writer can start typing
    // the title he came for the moment the page paints. 601, because the stylesheet takes
    // everything up to and including 600 as a phone.
    if (this.hasQueryTarget && window.matchMedia("(min-width: 601px)").matches) this.queryTarget.focus()
  }

  select(event) {
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-pressed", tab === event.currentTarget))

    this.reorder()
    this.filter()
  }

  filter() {
    const shown = this.rowTargets.filter((row) => {
      const match = this.inTab(row) && this.words.every((word) => row.dataset.search.includes(word))
      row.hidden = !match
      return match
    })

    this.report(shown.length)
  }

  // Sorting is the tab's business, not the query's, so it happens once when the tab
  // changes rather than on every keystroke — filtering only hides rows, which cannot
  // disturb the order of the ones left.
  reorder() {
    if (!this.hasListTarget) return

    const key = `data-${this.activeTab.dataset.sort}`
    const direction = Number(this.activeTab.dataset.direction)

    this.rowTargets
      .filter((row) => this.inTab(row))
      .sort((a, b) => direction * a.getAttribute(key).localeCompare(b.getAttribute(key)))
      .forEach((row) => this.listTarget.appendChild(row))
  }

  report(shown) {
    if (!this.hasEmptyTarget) return

    const label = this.activeTab.dataset.label
    this.emptyTarget.textContent = this.query
      ? `Nothing matches "${this.query}" in ${label}.`
      : `Nothing in ${label} yet.`
    this.emptyTarget.hidden = shown > 0
  }

  inTab(row) {
    const status = this.activeTab.dataset.status
    return status === "all" || row.dataset.status === status
  }

  get activeTab() {
    return this.tabTargets.find((tab) => tab.getAttribute("aria-pressed") === "true")
  }

  get query() {
    return this.hasQueryTarget ? this.queryTarget.value.trim() : ""
  }

  get words() {
    return this.query.toLowerCase().split(/\s+/).filter(Boolean)
  }
}
