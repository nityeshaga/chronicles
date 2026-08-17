import { Controller } from "@hotwired/stimulus"

// Suggest a slug from the title, but only while the slug field is untouched. The
// moment the writer edits the slug (or it arrived pre-filled), we back off — the
// field's own state is the source of truth, not a JS flag we have to keep in sync.
//
// Whether that slug is free is the server's answer, never this file's: check() points
// the status frame at the slug's own URL and Turbo fetches and swaps it. So there's no
// request code here, no JSON, and no second definition of "taken" to drift. The URL
// arrives whole from the server with a placeholder where the slug goes; the client
// assembles no paths of its own.
const DELAY = 300
const PLACEHOLDER = "SLUG"

export default class extends Controller {
  static targets = ["source", "slug", "status"]
  static values = { url: String, original: String }

  #timer

  connect() {
    this.auto = this.slugTarget.value.trim() === ""
  }

  disconnect() {
    clearTimeout(this.#timer)
  }

  edited() {
    this.auto = false
  }

  suggest() {
    if (!this.auto) return

    this.slugTarget.value = this.#slugify(this.sourceTarget.value)
    this.check()
  }

  // Debounced: a burst of keystrokes asks once, when the writer pauses.
  check() {
    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => this.#ask(), DELAY)
  }

  // Nothing to ask about a blank slug, or the one the record already has.
  #ask() {
    const slug = this.slugTarget.value.trim()
    if (slug === "" || slug === this.originalValue) return this.#clear()

    const url = new URL(this.urlValue.replace(PLACEHOLDER, encodeURIComponent(slug)), location.origin)
    url.searchParams.set("except", this.originalValue)
    this.statusTarget.src = url
  }

  #clear() {
    this.statusTarget.removeAttribute("src")
    this.statusTarget.innerHTML = ""
  }

  #slugify(value) {
    return value
      .toString()
      .toLowerCase()
      .trim()
      .replace(/[^\w\s-]/g, "")
      .replace(/[\s_]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "")
  }
}
