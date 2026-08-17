import { Controller } from "@hotwired/stimulus"

// Is this URL free? That is the whole job here. The answer is the server's, never this
// file's: check() points the status frame at the check URL and Turbo fetches and swaps
// it. So there is no request code here, no JSON, no second definition of "taken" to
// drift — and no rule about blank slugs either, since the server answers a blank one
// with the empty frame it already renders.
//
// Inventing a URL is the server's too. While the field is in auto mode it shows what the
// last save kept (kept()) and nothing else — a slug guessed here would be a URL the site
// does not serve, which is the lie this line exists to end. The writer's first keystroke
// ends auto mode for good, and the field is his from then on.
//
// Auto mode lives on the field as data-auto, stamped by the server (a new post, or a
// draft still wearing the placeholder title), because autosave has to read it too — it
// decides whether the slug rides the payload — and one attribute both can see beats two
// flags that agree until they don't.
//
// The record excludes itself from the answer by id, which arrives with the page — or, on
// a brand-new post, from autosave the moment it mints the draft (minted()).
const DELAY = 300

export default class extends Controller {
  static targets = ["slug", "status"]
  static values = { url: String, postId: String }

  #timer

  disconnect() {
    clearTimeout(this.#timer)
  }

  edited() {
    this.slugTarget.dataset.auto = false
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

  // What the server kept, from a save that settled the slug. In auto mode that is the
  // field's only source: a title that collides comes back suffixed, and hello-2 is what
  // the canvas must say. Once the writer owns the field it is left alone — a name he
  // typed that is taken stays on screen with the frame calling it taken, which is the
  // honest pair.
  kept({ detail: { slug } }) {
    if (this.slugTarget.dataset.auto !== "true" || this.slugTarget.value === slug) return

    this.slugTarget.value = slug
    this.check()
  }

  #ask() {
    const url = new URL(this.urlValue, location.origin)
    url.searchParams.set("slug", this.slugTarget.value.trim())
    url.searchParams.set("except", this.postIdValue)
    this.statusTarget.src = url
  }
}
