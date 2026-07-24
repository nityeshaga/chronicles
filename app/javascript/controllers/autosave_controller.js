import { Controller } from "@hotwired/stimulus"

// Debounced autosave. No dirty flag: "is a save pending?" and "is there unsaved work?"
// are the same question, so the timer IS the dirty bit (house pattern). Leaving the
// editor (disconnect) flushes any pending work.
//
// The save is a fetch, NOT a form submit: a plain PATCH the server answers with 204 on
// success and a bodyless 422 on failure, so a mid-typing validation error can never
// repaint the page — autosave is as invisible on failure as it is on success. Slug and
// the feature-image file are held OUT of this silent path (see #payload): they change the
// edit URL / upload bytes, so they commit only on an explicit blur (commit()), which is a
// normal Turbo submit that's allowed to redirect. A small status target narrates state.
//
// A brand-new post rides the same controller: until it's persisted the first save POSTs
// once to mint the draft (the instant there's real content — never on load), then adopts
// the persisted PATCH URL in place, so every later keystroke autosaves without a navigation.
const INTERVAL = 2000

export default class extends Controller {
  static targets = ["status", "slug", "file"]
  static values = { persisted: Boolean }

  #timer
  #creating = false

  disconnect() {
    this.flush()
  }

  // Both the plain fields and the <lexxy-editor> live inside this form; scope by
  // containment so an editor change and a plain input both count as one dirty bit. Slug
  // keystrokes are ignored here — the slug only commits on its own blur (commit()).
  change(event) {
    if (!this.element.contains(event.target)) return
    // The tag-mint input sits inside this form's DOM but is reassociated to #new-tag-form
    // via its `form` attribute, so its keystrokes aren't ours to save.
    if (event.target.form && event.target.form !== this.element) return
    if (this.hasSlugTarget && event.target === this.slugTarget) return

    this.#markUnsaved()
    if (!this.#dirty) this.#timer = setTimeout(() => this.#save(), INTERVAL)
  }

  flush() {
    if (this.#dirty) this.#save()
  }

  // An explicit save (slug/feature-image blur, or the Save button): a normal Turbo submit
  // so a renamed slug can redirect to the new edit URL and a real error can show itself.
  commit() {
    clearTimeout(this.#timer)
    this.#timer = null
    this.element.requestSubmit()
  }

  // Turbo tells us how the explicit submit resolved; mirror it in the indicator.
  committed(event) {
    this.#setStatus(event.detail.success ? "saved" : "error")
  }

  async #save() {
    clearTimeout(this.#timer)
    this.#timer = null

    // New post: mint the draft first, but only once there's real content and never twice
    // (a create in flight blocks a second). Once persisted this falls through to PATCH.
    if (!this.persistedValue) {
      if (this.#creating || !this.#hasContent) return this.#setStatus("")
      return this.#createDraft()
    }

    this.#setStatus("saving")
    try {
      const response = await fetch(this.element.action, {
        method: "PATCH",
        headers: { "X-Autosave": "true", "X-CSRF-Token": this.#csrfToken },
        body: this.#payload
      })
      this.#setStatus(this.#outcome(response))
    } catch {
      this.#setStatus("error")
    }
  }

  // First real keystroke on a new post: POST once to create the draft. The server answers
  // 201 with the edit URL in Location; we adopt it so every later save is a PATCH in place.
  async #createDraft() {
    this.#creating = true
    this.#setStatus("saving")
    try {
      const response = await fetch(this.element.action, {
        method: "POST",
        headers: { "X-Autosave": "true", "X-CSRF-Token": this.#csrfToken },
        body: this.#payload
      })
      if (response.status === 201) {
        this.#adoptPersistedUrl(response.headers.get("Location"))
        this.#setStatus("saved")
      } else {
        this.#setStatus(this.#outcome(response))
      }
    } catch {
      this.#setStatus("error")
    } finally {
      this.#creating = false
    }
  }

  // Turn a freshly-minted draft's form into the persisted one: Location carries the
  // created resource — the PATCH target — whole, so adopt it verbatim (the URL is the
  // contract; the client never derives it). A _method override makes an explicit
  // "Save draft" click land as a PATCH too.
  #adoptPersistedUrl(url) {
    if (!url) return
    this.element.action = url
    let method = this.element.querySelector("input[name='_method']")
    if (!method) {
      method = document.createElement("input")
      method.type = "hidden"
      method.name = "_method"
      this.element.prepend(method)
    }
    method.value = "patch"
    this.persistedValue = true
  }

  // A save "worked" only on a bare 204. Following a redirect to the sign-in page (a dead
  // session) would otherwise read as 200/ok and lie "Saved" while nothing persisted — so
  // a redirected response is called out distinctly, and anything else is a plain error.
  #outcome(response) {
    if (response.status === 204 || response.status === 201) return "saved"
    if (response.redirected) return "signedout"
    return "error"
  }

  // Is there anything worth minting a draft for? Title or body — matches the server guard.
  get #hasContent() {
    const data = new FormData(this.element)
    const title = (data.get("post[title]") || "").trim()
    const body = (data.get("post[body]") || "").replace(/<[^>]*>/g, "").replace(/&nbsp;/g, " ").trim()
    return title.length > 0 || body.length > 0
  }

  // Everything the form holds except the two fields that must not ride the silent path.
  get #payload() {
    const data = new FormData(this.element)
    if (this.hasSlugTarget) data.delete(this.slugTarget.name)
    if (this.hasFileTarget) data.delete(this.fileTarget.name)
    return data
  }

  get #dirty() {
    return !!this.#timer
  }

  get #csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  #markUnsaved() {
    if (!this.#dirty) this.#setStatus("unsaved")
  }

  #setStatus(state) {
    if (!this.hasStatusTarget) return
    this.statusTarget.dataset.state = state
    this.statusTarget.textContent = {
      unsaved: "Unsaved changes",
      saving: "Saving…",
      saved: "Saved",
      signedout: "Signed out — changes NOT saved",
      error: "Couldn't save"
    }[state] || ""
  }
}
