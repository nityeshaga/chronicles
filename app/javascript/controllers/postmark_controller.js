import { Controller } from "@hotwired/stimulus"

// The subscribe envelope is postmarked the first time someone writes on it: the stamp
// thumps in on focus and stays. Purely decorative — the form works without it.
export default class extends Controller {
  mark() {
    if (this.element.classList.contains("marked")) return

    this.element.classList.add("marked", "thump")
    setTimeout(() => this.element.classList.remove("thump"), 400)
  }
}
