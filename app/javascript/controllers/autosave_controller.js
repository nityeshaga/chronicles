import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Debounced autosave, and the only save this editor has. No dirty flag: "is a save
// pending?" and "is there unsaved work?" are the same question, so the timer IS the
// dirty bit (house pattern).
//
// The save is a fetch, NOT a form submit: a plain PATCH the server answers with 204 on
// success and a bodyless 422 on failure, so a mid-typing validation error can never
// repaint the page — autosave is as invisible on failure as it is on success. Only the
// feature-image file is held out of it (see #payload): it uploads bytes, so it commits on
// an explicit blur (commit()), a normal Turbo submit. Status targets narrate state; there
// are two (the editor bar and the settings panel head) and both get written.
//
// The slug rides this path too, which is the only way the URL on the canvas and the URL
// in the database can be the same string. A rename moves every address the editor is
// holding, so the 204 that carried it out hands them all back (#adoptUrls) and the editor
// re-points itself in place: form action, address bar, view button, and the field, which
// shows the slug the server actually kept rather than the one it was asked for.
//
// A brand-new post rides the same controller: until it's persisted the first save POSTs
// once to mint the draft (the instant there's real content — never on load), then adopts
// the persisted PATCH URL in place and renders the Turbo Stream that upgrades the editor
// to its saved shape, so every later keystroke autosaves without a navigation.
//
// Since there is no Save button, leaving is where work would be lost, so the exits are
// covered: an in-app Turbo visit is held until the pending save lands (guardVisit), and a
// tab close or reload raises the browser's own dialog (guardUnload). Neither blocks the
// writer; they only refuse to let a save disappear quietly.
//
// Back is the exception, and deliberately so: Turbo does not fire turbo:before-visit for
// history navigation, so guardVisit never sees it. It lands on one of the other two
// instead, depending on how the writer got here. Reached by a Turbo visit (the usual
// way — New post from the dashboard), Back is a restore visit: the document survives, so
// disconnect() flushes and the fetch completes. Reached any other way (a typed URL, a
// fresh tab), Back is a real unload and guardUnload's dialog catches it. Both were
// checked in a browser; neither is visible to the rack_test suite.
//
// The gap that leaves is narrow and real: on the restore path nothing awaits the flush,
// so a save that FAILS during a Back goes unreported. Reporting it would mean holding a
// navigation the browser has already committed to, which is not ours to hold.
const INTERVAL = 2000
// Work that would be lost if the document went away now: a save still to come, one that
// failed (nothing retries it), or a session that died under it. Both leave guards read
// this one list.
const AT_RISK = ["unsaved", "saving", "error", "refused", "signedout"]

export default class extends Controller {
  static targets = ["status", "slug", "file", "viewLink"]
  // savedText is written by the server: what "saved" means depends on where the post
  // stands (a live post's save republished the page), and that copy is Ruby's to own.
  static values = { persisted: Boolean, savedText: String }

  #timer
  #creating = false
  #state = ""
  // The one exit already refused out loud. Cleared by a save that works, so the warning
  // is about work that is still unsaved and never about work that since landed.
  #refusedUrl
  // The save in flight, so callers that must not race it — Publish, an in-app exit —
  // can await the very same promise instead of guessing at a delay.
  #pending = Promise.resolve()
  // Is the writer mid-edit in the URL field? Only he types there — auto mode writes the
  // field programmatically — so an input event on it means the slug is half a thought,
  // and half a thought is not a rename.
  #slugHeld = false

  disconnect() {
    this.flush()
  }

  // Both the plain fields and the <lexxy-editor> live inside this form; scope by
  // containment so an editor change and a plain input both count as one dirty bit. Slug
  // keystrokes skip the debounce: a URL lands when the writer is done with it, not two
  // seconds into typing it (holdSlug / commitSlug).
  change(event) {
    if (!this.element.contains(event.target)) return
    // The tag-mint input sits inside this form's DOM but is reassociated to #new-tag-form
    // via its `form` attribute, so its keystrokes aren't ours to save.
    if (event.target.form && event.target.form !== this.element) return
    if (this.hasSlugTarget && event.target === this.slugTarget) return

    this.#markUnsaved()
    if (!this.#dirty) this.#timer = setTimeout(() => this.#save(), INTERVAL)
  }

  // The URL is a decision, not a keystroke. While it's being typed it stays out of the
  // payload; the moment the writer is done with it — a change event, so blur or Enter —
  // it lands immediately rather than in two seconds, because the address bar and the view
  // button move with it and they should move while he's still looking at them.
  holdSlug() {
    this.#slugHeld = true
    this.#markUnsaved()
  }

  commitSlug() {
    this.#slugHeld = false
    this.#save()
  }

  // Run any pending work now and hand back the promise for it, so a caller can wait. A
  // slug still being typed counts as pending work: the leave guards ask this question by
  // flushing, and a URL held out of the payload would otherwise be unsaved work nothing
  // could land, so the guard would refuse an exit it had no way to satisfy.
  flush() {
    if (this.#slugHeld) this.commitSlug()
    else if (this.#dirty) this.#save()
    return this.#pending
  }

  // An explicit save (the feature-image file): a normal Turbo submit, because bytes need
  // one and a real error there should show itself.
  commit() {
    clearTimeout(this.#timer)
    this.#timer = null
    this.element.requestSubmit()
  }

  // Turbo tells us how the explicit submit resolved; mirror it in the indicator.
  committed(event) {
    this.#setStatus(event.detail.success ? "saved" : "error")
  }

  // In-app exit (‹ Writing, any Turbo link). Hold the visit, land the save, then make the
  // visit ourselves. If the save fails, the first attempt is refused and the bar says so;
  // the same click again goes through. One refusal, not a cell: the writer is allowed to
  // abandon work he has been told is unsaved, and a guard he cannot get past would be a
  // worse bug than the one it prevents.
  async guardVisit(event) {
    const url = event.detail.url
    if (this.#refusedUrl === url || !this.#atRisk) return

    event.preventDefault()
    await this.flush()

    if (this.#atRisk) {
      this.#refusedUrl = url
      this.#setStatus("refused")
    } else {
      Turbo.visit(url)
    }
  }

  // Tab close, reload, typed URL. Nothing can be awaited here, so the honest move is the
  // browser's own "Leave site?" dialog rather than a best-effort send that silently drops
  // bodies over 64 KB.
  guardUnload(event) {
    if (!this.#atRisk) return

    event.preventDefault()
    event.returnValue = ""
  }

  #save() {
    clearTimeout(this.#timer)
    this.#timer = null
    return this.#pending = this.#run()
  }

  async #run() {
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
      if (response.status === 204) this.#adoptUrls(response)
      this.#setStatus(this.#outcome(response))
    } catch {
      this.#setStatus("error")
    }
  }

  // First real keystroke on a new post: POST once to create the draft. The server answers
  // 201 with the edit URL in Location (adopted so every later save is a PATCH in place),
  // the record's id in X-Post-Id (announced to the rest of the form), and a Turbo Stream
  // carrying the chrome only a saved post can wear.
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
        this.#adoptUrls(response)
        // The draft now exists, so anything on this form that has to name the record can
        // stop guessing: announce the id the server just handed back (the slug check
        // listens, to stop counting the draft's own slug against it).
        this.dispatch("minted", { detail: { id: response.headers.get("X-Post-Id") } })
        Turbo.renderStreamMessage(await response.text())
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

  // Where the record lives now, as the server just told it: the mint says so once, and a
  // save that renamed the slug says so again. Both answers carry the same headers because
  // the same four things move — the PATCH target, the address bar, the view button, and
  // the slug itself, which the server may have kept differently (hello-2 on a collision,
  // or the old one if the wanted name was taken). A bare 204 carries none of them and
  // this is a no-op. Every URL arrives whole; none is assembled here out of a slug.
  #adoptUrls(response) {
    this.#adoptPersistedUrl(response.headers.get("Location"))
    this.#adoptEditUrl(response.headers.get("X-Edit-Url"))

    const slug = response.headers.get("X-Slug")
    if (!slug) return
    if (this.hasViewLinkTarget) this.viewLinkTarget.href = response.headers.get("X-View-Url")
    this.dispatch("slugged", { detail: { slug } })
  }

  // Turn a freshly-minted draft's form into the persisted one: Location carries the
  // created resource — the PATCH target — whole, so adopt it verbatim (the URL is the
  // contract; the client never derives it). A _method override makes any later explicit
  // submit of this form land as a PATCH too.
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

  // The address bar still says /writing/posts/new; move it onto the draft so a refresh
  // reopens the work instead of a blank canvas. Server-built and handed over in a header,
  // like the PATCH target — the client never derives a URL.
  #adoptEditUrl(url) {
    if (url) history.replaceState(history.state, "", url)
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
  // Found by field suffix rather than a literal `post[title]`: this same form is the page
  // editor too, where every field is named `page[…]`, and naming one of them made new
  // pages silently unmintable.
  get #hasContent() {
    const title = this.#field("title").trim()
    const body = this.#field("body").replace(/<[^>]*>/g, "").replace(/&nbsp;/g, " ").trim()
    return title.length > 0 || body.length > 0
  }

  #field(name) {
    return this.element.querySelector(`[name$='[${name}]']`)?.value || ""
  }

  // Everything the form holds, minus what doesn't belong in this particular request. The
  // feature image is bytes and rides its own Turbo submit. The slug rides along — that is
  // how the canvas and the database keep the same URL — except while it's being typed,
  // and except on the mint: a brand-new post lets the server invent its slug, so a title
  // that collides comes back as hello-2 instead of failing a uniqueness validation.
  get #payload() {
    const data = new FormData(this.element)
    if (this.hasFileTarget) data.delete(this.fileTarget.name)
    if (this.hasSlugTarget && (this.#slugHeld || !this.persistedValue)) data.delete(this.slugTarget.name)
    return data
  }

  get #dirty() {
    return !!this.#timer
  }

  get #atRisk() {
    return AT_RISK.includes(this.#state)
  }

  get #csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  #markUnsaved() {
    if (!this.#dirty) this.#setStatus("unsaved")
  }

  #setStatus(state) {
    this.#state = state
    if (state === "saved") this.#refusedUrl = null

    const text = {
      unsaved: "Unsaved changes",
      saving: "Saving…",
      saved: this.savedTextValue,
      signedout: "Signed out — changes NOT saved",
      error: "Couldn't save",
      refused: "Couldn't save — click again to leave anyway"
    }[state] || ""

    for (const target of this.statusTargets) {
      target.dataset.state = state
      target.textContent = text
    }
  }
}
