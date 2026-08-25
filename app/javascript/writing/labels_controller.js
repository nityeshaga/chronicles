import { Controller } from "@hotwired/stimulus"

// Lexxy generates two sets of toolbar buttons from its config and names neither for a
// screen reader: the colour palette — eighteen buttons "color-0" … "background-color-8",
// each a coloured "Aa" — and the heading items, which it labels Large/Medium/Small. The
// names live here in the markup: swatches in the palette's own order, headings by tag.
// Lexxy reports itself ready once the buttons exist, and again after every reconnect,
// which regenerates them; but the editor upgrades before Stimulus starts, so on a fresh
// page that report can land before this connects — hence both. Labelling is idempotent,
// so running twice costs nothing.
export default class extends Controller {
  static values = { swatches: String, headings: Object }

  connect() {
    this.label()
  }

  label() {
    this.#labelSwatches()
    this.#labelHeadings()
  }

  #labelSwatches() {
    const names = this.swatchesValue.split(/\s+/)

    for (const swatch of this.element.querySelectorAll(".lexxy-highlight-button")) {
      const [ , kind, index ] = swatch.name.match(/^(.+)-(\d+)$/)
      this.#name(swatch, `${names[index]} ${kind === "color" ? "text" : "background"}`)
    }
  }

  #labelHeadings() {
    for (const heading of this.element.querySelectorAll(".lexxy-heading-button")) {
      const name = this.headingsValue[heading.dataset.heading]
      if (!name) continue

      heading.querySelector("span").textContent = name
      this.#name(heading, name)
    }
  }

  #name(button, name) {
    button.title = name
    button.setAttribute("aria-label", name)
  }
}
