import { Controller } from "@hotwired/stimulus"

// The editor's two overlays: the "Post settings" slide-over (slug, tags, metadata) and
// the "Publish" popover. Only one is open at a time; a shared backdrop, the Escape key,
// and clicking an open toggle again all close whatever's showing. State is a single class
// on each element — no JS bookkeeping beyond "which one, if any." The panels stay in the
// DOM (and stay reachable to non-JS test drivers); this only toggles their visibility.
//
// It also owns the two things inside the popover that depend on the canvas outside it:
// whether the post has a title yet (retitle), and the rule that publishing never
// overtakes a save still in flight (commitThenSubmit).
export default class extends Controller {
  static targets = ["settings", "publish", "backdrop", "titleNote", "publishSubmit"]
  static classes = ["open"]
  static outlets = ["autosave"]
  static values = { openPublish: Boolean }

  // The server decides this one: an arrival that came from a publishing action says so,
  // and the answer — LIVE, SCHEDULED, or the refusal — is showing before the writer has
  // to know there is a click that would show it. It rides a one-shot flash, so a Back or
  // a Turbo restore lands on a page that no longer asks for it.
  connect() {
    if (this.openPublishValue && this.hasPublishTarget) this.#show(this.publishTarget)
  }

  // Turbo caches the DOM as it stands and repaints that on a restore visit, so a panel
  // left open would come back open on a Back the writer meant as "leave" — and the
  // server's one-shot instruction would still be sitting in the snapshot to reopen it a
  // second time. Both are transient state; neither belongs in the cache.
  beforeCache() {
    this.openPublishValue = false
    this.close()
  }

  toggleSettings(event) {
    event.preventDefault()
    this.#show(this.settingsTarget.classList.contains(this.openClass) ? null : this.settingsTarget)
  }

  togglePublish(event) {
    event.preventDefault()
    this.#show(this.publishTarget.classList.contains(this.openClass) ? null : this.publishTarget)
  }

  close() {
    this.#show(null)
  }

  // The popover's note and its disabled Publish are rendered from the record, but the
  // title is being typed a metre away — so keep them honest as it's typed rather than
  // making the writer close and reopen the popover to find out he's allowed now.
  retitle(event) {
    const titled = event.target.value.trim().length > 0
    if (this.hasTitleNoteTarget) this.titleNoteTarget.hidden = titled
    if (this.hasPublishSubmitTarget) this.publishSubmitTarget.disabled = !titled
  }

  // Publishing re-renders the canvas from the record, so it must never overtake a save
  // still in flight: the page would come back with an older body, and the pending PATCH
  // would then write that body over the newer one. Wait, then submit for real.
  //
  // Bound to the button's click, not the form's submit: a requestSubmit() issued from
  // inside a submit handler lands while the form is still firing submission events and
  // is silently dropped. The click is outside that window.
  async commitThenSubmit(event) {
    event.preventDefault()
    const submitter = event.currentTarget
    if (this.hasAutosaveOutlet) await this.autosaveOutlet.flush()
    submitter.form.requestSubmit(submitter)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  #show(panel) {
    for (const target of this.#panels) {
      target.classList.toggle(this.openClass, target === panel)
    }
    this.backdropTarget.classList.toggle(this.openClass, panel !== null)
  }

  get #panels() {
    return [this.settingsTarget, this.hasPublishTarget ? this.publishTarget : null].filter(Boolean)
  }
}
