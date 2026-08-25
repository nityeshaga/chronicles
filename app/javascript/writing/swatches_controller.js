import { Controller } from "@hotwired/stimulus"

// Lexxy generates the colour palette from its config — eighteen buttons named
// "color-0" … "background-color-8", with a coloured "Aa" and no accessible name. The
// names live here in the markup, in the palette's own order; this reads each button's
// kind and index and says which colour it is. Lexxy reports itself ready once the buttons
// exist, and again after every reconnect, which regenerates them; but the editor upgrades
// before Stimulus starts, so on a fresh page that report can land before this connects —
// hence both. Labelling is idempotent, so running twice costs nothing.
export default class extends Controller {
  static values = { names: String }

  connect() {
    this.label()
  }

  label() {
    const names = this.namesValue.split(/\s+/)

    for (const swatch of this.element.querySelectorAll(".lexxy-highlight-button")) {
      const [ , kind, index ] = swatch.name.match(/^(.+)-(\d+)$/)
      const label = `${names[index]} ${kind === "color" ? "text" : "background"}`
      swatch.title = label
      swatch.setAttribute("aria-label", label)
    }
  }
}
