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
// in the database can be the same string. It rides it by NOT being sent while the field
// is still following the title (data-auto on the field): the server derives the slug from
// the title and hands back what it kept, so no guess made here can outlive one save.
// Once the writer takes the field over, it is sent — but only when he is done typing it.
//
// A save that moves the slug moves everything the editor is holding with it: the PATCH
// target, the address bar, and every id and URL in the saved-post chrome. So a rename is
// answered exactly like the mint — the same Turbo Stream, the same three headers — and
// #adopt installs both without a reload and without moving the caret.
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
//
// Saves go out one at a time: each chains onto the one before it, so a slug commit and a
// timer firing during a slow response can never have two PATCHes in flight with the
// server free to land the older body last. A failed save leaves nothing armed and nothing
// remembered — the next keystroke arms the timer again, and that IS the retry.
//
// Two tabs on one post are told apart by the record's lock_version, which the form
// carries and every landed save hands back (X-Lock-Version) for this tab to adopt. A tab
// that fell behind gets a 409: the bar says so, saving stops, and only a reload — the
// writer's, with his eyes on both versions — continues. Nothing here tries to merge.
//
// A save that lands is announced (autosave:saved) so whatever else holds a copy of the
// work — the local draft — can let it go.
const INTERVAL = 2000
// Work that would be lost if the document went away now: a save still to come, one that
// failed, a session that died under it, or a record another tab moved on. Both leave
// guards read this one list.
const AT_RISK = ["unsaved", "saving", "error", "refused", "signedout", "stale"]

export default class extends Controller {
  static targets = ["status", "slug", "file", "lock"]
  // savedText is written by the server: what "saved" means depends on where the post
  // stands (a live post's save republished the page), and that copy is Ruby's to own.
  static values = { persisted: Boolean, savedText: String }

  #timer
  #state = ""
  // The one exit already refused out loud. Cleared by a save that works, so the warning
  // is about work that is still unsaved and never about work that since landed.
  #refusedUrl
  // Every save so far, chained: the next one starts when this settles, and callers that
  // must not race a save — Publish, an in-app exit — await the very same promise.
  #pending = Promise.resolve()

  disconnect() {
    this.flush()
  }

  // Both the plain fields and the <lexxy-editor> live inside this form; scope by
  // containment so an editor change and a plain input both count as one dirty bit. Slug
  // keystrokes skip the debounce: a URL lands when the writer is done with it, not two
  // seconds into typing it (holdSlug / commitSlug).
  change(event) {
    if (this.#stale || !this.element.contains(event.target)) return
    // The tag-mint input sits inside this form's DOM but is reassociated to #new-tag-form
    // via its `form` attribute, so its keystrokes aren't ours to save.
    if (event.target.form && event.target.form !== this.element) return
    if (this.hasSlugTarget && event.target === this.slugTarget) return

    this.#markUnsaved()
    if (!this.#dirty) this.#timer = setTimeout(() => this.#save(), INTERVAL)
  }

  // The URL is a decision, not a keystroke: while it's being typed it stays out of the
  // payload, and the moment the writer is done with it — a change event — it lands
  // immediately rather than in two seconds, because the address bar moves with it and it
  // should move while he's still looking at it. The blur is for the Enter key, which
  // announces the change without giving the field up; without it the field would still
  // read as held and the save it just asked for would go out without it.
  commitSlug() {
    this.slugTarget.blur()
    this.#save()
  }

  // ⌘S. There is no Save button and the timer would have landed this in two seconds
  // anyway, so the key exists to answer the reflex — the bar says "Saving…" and then
  // "Saved", which is the whole point of pressing it. Nothing waits on the result here.
  flushNow() {
    this.flush()
  }

  // Run any pending work now and hand back the promise for it, so a caller can wait.
  flush() {
    if (this.#dirty) this.#save()
    return this.#pending
  }

  // An explicit save (the feature-image file): a normal Turbo submit, because bytes need
  // one and a real error there should show itself.
  commit() {
    if (this.#stale) return
    clearTimeout(this.#timer)
    this.#timer = null
    this.element.requestSubmit()
  }

  // The chrome the server sends is stateless: it cannot know the writer has the publish
  // popover open on top of it, and a morph would reconcile that class away and leave him
  // with a greyed page and nothing on it. So a panel that is open keeps its class list;
  // every other attribute on every other element morphs as usual. The class is read off
  // the markup rather than named here — it stays the editor controller's to choose.
  keepPanelOpen(event) {
    const openClass = this.element.closest("[data-editor-open-class]")?.dataset.editorOpenClass
    if (!openClass || event.detail.attributeName !== "class") return
    if (event.target.classList.contains(openClass)) event.preventDefault()
  }

  // Turbo tells us how the explicit submit resolved; mirror it in the indicator, and take
  // the version it made — a save is a save, whichever wire it rode. A followed redirect is
  // the server taking the page over (a rename, or a refusal), and what it meant is said
  // on the page that arrives. Calling it "saved" here would let the local draft go first;
  // leaving it at risk would have guardVisit refuse the very visit that carries the
  // answer. So the bar goes quiet and the next page speaks.
  committed(event) {
    const response = event.detail.fetchResponse
    if (response?.redirected) return this.#setStatus("")

    this.#adoptLockVersion(response?.header("X-Lock-Version"))
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
      // A stale tab stays stale: the bar already names the one way out, and saying
      // anything else here would let saving quietly resume against a record that moved.
      if (!this.#stale) this.#setStatus("refused")
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
    if (this.#stale) return this.#pending
    return this.#pending = this.#pending.then(() => this.#run())
  }

  async #run() {
    // New post: mint the draft first, but only once there's real content. Saves run one
    // at a time, so a second mint can't start under the first; once persisted this falls
    // through to PATCH.
    if (!this.persistedValue) {
      return this.#hasContent ? this.#createDraft() : this.#setStatus("")
    }

    this.#setStatus("saving")
    try {
      const response = await fetch(this.element.action, {
        method: "PATCH",
        headers: { "X-Autosave": "true", "X-CSRF-Token": this.#csrfToken },
        body: this.#payload
      })
      await this.#adopt(response)
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
    this.#setStatus("saving")
    try {
      const response = await fetch(this.element.action, {
        method: "POST",
        headers: { "X-Autosave": "true", "X-CSRF-Token": this.#csrfToken },
        body: this.#payload
      })
      if (response.status === 201) {
        // The draft now exists, so anything on this form that has to name the record can
        // stop guessing: announce the id the server just handed back (the slug check
        // listens, to stop counting the draft's own slug against it) and the slot the
        // local draft now belongs in (local-save moves its copy over).
        this.dispatch("minted", { detail: {
          id: response.headers.get("X-Post-Id"),
          localSaveKey: response.headers.get("X-Local-Save-Key")
        } })
      }
      await this.#adopt(response)
      this.#setStatus(this.#outcome(response))
    } catch {
      this.#setStatus("error")
    }
  }

  // Where the record lives now, as the server just told it. The mint says so once and a
  // rename says so again, in the same answer: the PATCH target (Location), the address
  // bar (X-Edit-Url), the slug actually kept (X-Slug — hello-2 where hello was taken),
  // and a Turbo Stream carrying the chrome that
  // addresses this record — Publish, its popover, Delete, the tag mint — re-stamped from
  // the one place each of them is written. An ordinary keystroke save is a bare 204 that
  // carries only the version it made. Every URL arrives whole; none is assembled here
  // out of a slug.
  async #adopt(response) {
    // A dead session answers 200 too, with the sign-in page — nothing to adopt there.
    if (response.redirected) return

    this.#adoptLockVersion(response.headers.get("X-Lock-Version"))
    if (![ 200, 201 ].includes(response.status)) return

    this.#adoptPersistedUrl(response.headers.get("Location"))
    this.#adoptEditUrl(response.headers.get("X-Edit-Url"))
    this.dispatch("slugged", { detail: { slug: response.headers.get("X-Slug") } })
    Turbo.renderStreamMessage(await response.text())
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

  // The version the save just made, so the next save names the record as it now stands.
  // Only answers that made one carry it; a refusal leaves the field as it was.
  #adoptLockVersion(version) {
    if (version != null && this.hasLockTarget) this.lockTarget.value = version
  }

  // A save worked on 204 (nothing moved), 201 (the mint) or 200 (a rename's chrome).
  // Following a redirect to the sign-in page (a dead session) also arrives as a 200, and
  // would lie "Saved" while nothing persisted — so that question is asked first. A 409
  // is another tab having saved first.
  #outcome(response) {
    if (response.redirected) return "signedout"
    if ([ 200, 201, 204 ].includes(response.status)) return "saved"
    if (response.status === 409) return "stale"
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
  // feature image is bytes and rides its own Turbo submit. The slug is sent only when the
  // writer owns it and has finished typing it: while the field follows the title, sending
  // nothing is what lets the server derive the URL and hand back what it kept.
  get #payload() {
    const data = new FormData(this.element)
    if (this.hasFileTarget) data.delete(this.fileTarget.name)
    if (this.hasSlugTarget && (this.#slugAuto || this.#slugHeld)) data.delete(this.slugTarget.name)
    return data
  }

  // Who owns the URL right now. Auto: the editor is still inventing it, so it is the
  // server's to derive and nothing here may send one. Held: it is under the caret, and
  // half a thought is not a rename — the DOM knows both, so nothing here has to remember
  // (a flag once stuck held after a writer typed an edit and undid it, and quietly took
  // the URL back off every save for the rest of the session).
  get #slugAuto() {
    return this.slugTarget.dataset.auto === "true"
  }

  get #slugHeld() {
    return document.activeElement === this.slugTarget
  }

  get #dirty() {
    return !!this.#timer
  }

  get #atRisk() {
    return AT_RISK.includes(this.#state)
  }

  // Another tab saved over this one. Read off the state the bar already shows, so there
  // is no second flag to fall out of step with it.
  get #stale() {
    return this.#state === "stale"
  }

  get #csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  #markUnsaved() {
    if (!this.#dirty) this.#setStatus("unsaved")
  }

  #setStatus(state) {
    this.#state = state
    if (state === "saved") {
      this.#refusedUrl = null
      this.dispatch("saved")
    }

    const text = {
      unsaved: "Unsaved changes",
      saving: "Saving…",
      saved: this.savedTextValue,
      signedout: "Signed out — changes NOT saved",
      stale: "Edited elsewhere — reload to continue",
      error: "Couldn't save",
      refused: "Couldn't save — click again to leave anyway"
    }[state] || ""

    for (const target of this.statusTargets) {
      target.dataset.state = state
      target.textContent = text
    }
  }
}
