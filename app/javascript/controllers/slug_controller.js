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
// Auto mode lives on the field as data-auto, because autosave has to read it too — it
// decides whether the slug rides the payload — and one attribute both can see beats two
// flags that agree until they don't. It means "this URL is still the editor's invention".
// The server seeds it off the record (a new post, or one still wearing the placeholder
// title: no title anyone chose, so no URL anyone chose) and the writer's first keystroke
// here ends it. A reload is not memory, so it asks the record again and errs towards
// leaving an existing URL alone — the imported archive is full of hand-curated slugs that
// no retitle should quietly rewrite.
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

  // What the server kept, from a save that moved the slug — and it only says so when the
  // slug moved, so this is never the answer to a refusal. The server is the truth about
  // the URL whoever asked: a title that collides comes back suffixed, and so does a name
  // the writer typed on a post too new to have one to keep. A refused rename sends
  // nothing here, which is what leaves the name he typed on screen with the frame calling
  // it taken — the honest pair.
  kept({ detail: { slug } }) {
    if (!slug || this.slugTarget.value === slug) return

    this.slugTarget.value = this.slugTarget.defaultValue = slug
    this.check()
  }

  // An empty URL is not a name the writer chose, it is the absence of one, and the post
  // still answers to the one the server last confirmed — which is what the field's own
  // default value is, kept in step by kept(). Put it back rather than commit a blank and
  // leave the line reading as though the post had no address.
  restore() {
    if (this.slugTarget.value.trim() === "") this.slugTarget.value = this.slugTarget.defaultValue
  }

  #ask() {
    const url = new URL(this.urlValue, location.origin)
    url.searchParams.set("slug", this.slugTarget.value.trim())
    url.searchParams.set("except", this.postIdValue)
    this.statusTarget.src = url
  }
}
