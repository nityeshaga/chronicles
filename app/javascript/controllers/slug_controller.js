import { Controller } from "@hotwired/stimulus"

// Suggest a slug from the title, but only while the slug field is untouched. The
// moment the writer edits the slug (or it arrived pre-filled), we back off — the
// field's own state is the source of truth, not a JS flag we have to keep in sync.
//
// Whether that slug is free is the server's answer, never this file's: check() points the
// status frame at the check URL and Turbo fetches and swaps it. So there's no request code
// here, no JSON, no second definition of "taken" to drift — and no rule about blank slugs
// either, since the server answers a blank one with the empty frame it already renders.
//
// The record excludes itself from the answer by id, which arrives with the page — or, on a
// brand-new post, from autosave the moment it mints the draft (minted()).
const DELAY = 300

export default class extends Controller {
  static targets = ["source", "slug", "status"]
  static values = { url: String, postId: String }

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

  // Autosave has just minted the draft this form edits. Take the id it announces and ask
  // again, so the record stops being told its own slug is taken.
  minted({ detail: { id } }) {
    this.postIdValue = id
    this.check()
  }

  // What the server kept, after a save that touched the slug. While the field is still
  // following the title it shows that answer rather than its own suggestion — a collision
  // is kept as hello-2, and the canvas has to say hello-2. Once the writer has taken the
  // field over it is his; a name that was taken stays on screen with the check calling it
  // taken, which is the honest pair.
  kept({ detail: { slug } }) {
    if (this.auto) this.slugTarget.value = slug
  }

  #ask() {
    const url = new URL(this.urlValue, location.origin)
    url.searchParams.set("slug", this.slugTarget.value.trim())
    url.searchParams.set("except", this.postIdValue)
    this.statusTarget.src = url
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
