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
//
// And it owns the keyboard's half of the same overlays: ⌘⇧P for publishing, ⌘P for the
// reader's view, ⌘/ for the shortcut sheet. A panel opened from the keyboard has to be
// usable from the keyboard, so opening one moves focus in, holds it there while it's
// open, and hands it back to whatever opened it — otherwise Tab walks the prose behind
// a panel the writer can see but can't reach.
// input[type=hidden] answers every other part of this selector and can never take
// focus: the tags field ships one, and at an edge of the list it would end the trap.
const FOCUSABLE = "a[href], button:not([disabled]), input:not([type=hidden]):not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"

export default class extends Controller {
  static targets = ["settings", "publish", "backdrop", "titleNote", "publishSubmit", "preview", "shortcuts"]
  static classes = ["open"]
  static outlets = ["autosave"]
  static values = { openPublish: Boolean }

  // Where focus was when a panel took it. Held for exactly as long as one is open.
  #focusReturn

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
    this.closeShortcuts()
    this.close()
  }

  toggleSettings(event) {
    event.preventDefault()
    this.#show(this.settingsTarget.classList.contains(this.openClass) ? null : this.settingsTarget)
  }

  // Also ⌘⇧P, which two states refuse: a canvas with nothing saved has no popover to
  // open, and neither key may open one behind the shortcut sheet's backdrop, where the
  // writer would see it and not be able to reach it.
  togglePublish(event) {
    event.preventDefault()
    if (!this.hasPublishTarget || this.#shortcutsOpen) return

    this.#show(this.publishTarget.classList.contains(this.openClass) ? null : this.publishTarget)
  }

  // ⌘P. The URL comes off the bar's own link — it already knows whether this post has a
  // preview or a live page, and the server stamped the address — but the tab is opened
  // here rather than by clicking it: the live button navigates in place, and a keystroke
  // that took the writer out of the editor mid-sentence would be a worse feature than no
  // keystroke. A window.open inside a key handler is still the gesture a blocker asks for.
  preview() {
    if (!this.hasPreviewTarget || this.#shortcutsOpen) return

    window.open(this.previewTarget.href, "_blank", "noopener")
  }

  close() {
    this.#show(null)
  }

  // ⌘/ and the link at the foot of the settings panel. A real <dialog>, so the platform
  // does the modal work this controller does by hand for the panels — focus in, Tab
  // trapped, Escape, focus back — and the sheet is the same markup either way.
  openShortcuts() {
    if (this.hasShortcutsTarget && !this.shortcutsTarget.open) this.shortcutsTarget.showModal()
  }

  closeShortcuts() {
    if (this.#shortcutsOpen) this.shortcutsTarget.close()
  }

  // Stimulus's key filters don't cover "/", so this combination is read here.
  shortcutsOnSlash(event) {
    if (event.key !== "/" || !(event.metaKey || event.ctrlKey)) return

    event.preventDefault()
    this.openShortcuts()
  }

  // A modal dialog's backdrop is the dialog's own box, so a click that landed on the
  // element itself landed outside the sheet.
  closeShortcutsOnBackdrop(event) {
    if (event.target === this.shortcutsTarget) this.closeShortcuts()
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

  // The sheet is a modal dialog and closes itself on Escape; the panel underneath it is
  // not what the writer was asking to leave.
  closeOnEscape(event) {
    if (event.key !== "Escape" || this.#shortcutsOpen) return

    this.close()
  }

  // Tab inside an open panel stays inside it: off the last control it wraps to the
  // first, and Shift+Tab off the first wraps to the last. Without this the next Tab
  // leaves for the prose behind the panel, where the writer can't see what he's typing
  // into. The dialog does its own trapping, so it takes its own Tabs.
  trapFocus(event) {
    if (event.key !== "Tab" || this.#shortcutsOpen) return

    const panel = this.#openPanel
    if (!panel) return

    const focusables = this.#focusablesIn(panel)
    if (focusables.length === 0) return

    const edge = event.shiftKey ? focusables[0] : focusables[focusables.length - 1]
    if (document.activeElement !== edge && panel.contains(document.activeElement)) return

    event.preventDefault()
    ;(event.shiftKey ? focusables[focusables.length - 1] : focusables[0]).focus()
  }

  #show(panel) {
    for (const target of this.#panels) {
      target.classList.toggle(this.openClass, target === panel)
    }
    this.backdropTarget.classList.toggle(this.openClass, panel !== null)
    this.#moveFocus(panel)
  }

  #moveFocus(panel) {
    if (panel) {
      this.#focusReturn ||= this.#focusableActiveElement
      this.#focusablesIn(panel)[0]?.focus()
    } else if (this.#focusReturn) {
      // A rename morphs the bar, so the button that opened the panel may be a different
      // element by the time it closes; there is nowhere to hand focus back to then.
      if (this.#focusReturn.isConnected) this.#focusReturn.focus()
      this.#focusReturn = null
    }
  }

  #focusablesIn(panel) {
    return Array.from(panel.querySelectorAll(FOCUSABLE))
  }

  get #focusableActiveElement() {
    const active = document.activeElement
    return active && active !== document.body ? active : null
  }

  get #openPanel() {
    return this.#panels.find(panel => panel.classList.contains(this.openClass)) || null
  }

  get #shortcutsOpen() {
    return this.hasShortcutsTarget && this.shortcutsTarget.open
  }

  get #panels() {
    return [this.settingsTarget, this.hasPublishTarget ? this.publishTarget : null].filter(Boolean)
  }
}
