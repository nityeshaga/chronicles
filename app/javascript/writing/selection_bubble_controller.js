import { Controller } from "@hotwired/stimulus"

// The two bubbles that follow the caret: formats over a selection, a link's address under
// a caret that sits inside one. It dispatches nothing itself — every button names a
// toolbar button and its click is forwarded there, so the toolbar stays the one place a
// command lives and this file can never drift from it.
//
// Two things Lexxy will not tell us. `lexxy:attributes-change` is dispatched only by the
// Hotwire Native adapter, so a browser never sees it — the caret is read from the
// document's own `selectionchange` instead. And a button's pressed state is painted by
// the toolbar on every editor update, so rather than asking the editor a second question
// we mirror the answer it already wrote: a MutationObserver on the toolbar's aria-pressed.
const SKIP = "pre, code, figure"

export default class extends Controller {
  static targets = ["format", "link", "href"]

  connect() {
    this.observer = new MutationObserver(() => this.#paintPressed())
    if (this.#toolbar) {
      this.observer.observe(this.#toolbar, { attributes: true, attributeFilter: ["aria-pressed"], subtree: true })
    }
  }

  disconnect() {
    this.observer.disconnect()
    cancelAnimationFrame(this.frame)
    this.frame = null
  }

  // selectionchange fires per keystroke of a Shift+arrow drag; one frame's worth of them
  // is one answer.
  follow() {
    if (this.frame) return

    this.frame = requestAnimationFrame(() => {
      this.frame = null
      this.#reveal()
    })
  }

  dismiss() {
    this.formatTarget.hidden = true
    this.linkTarget.hidden = true
  }

  dismissOnEscape(event) {
    if (event.key === "Escape") this.dismiss()
  }

  // The click must land while the words are still selected, and a press inside the bubble
  // would move the selection to the bubble. Refusing the mousedown leaves it where it is.
  keepSelection(event) {
    event.preventDefault()
  }

  // Not element.click(): that dispatches a PointerEvent with pointerId -1, which is how
  // Chrome reports a button activated from the keyboard, and Lexxy reads it as one — it
  // then tags the update "skip-dom-selection", which is right when the toolbar button
  // holds focus and wrong here, where the words are still selected and must stay that way
  // (the reconcile replaces their text nodes and the caret collapses). A pointer's event
  // takes the branch a real click takes.
  proxy(event) {
    const button = event.target.closest("[data-for]")
    if (!button) return

    this.#toolbarButton(button.dataset.for)
      ?.dispatchEvent(new PointerEvent("click", { bubbles: true, cancelable: true, pointerId: 1 }))
  }

  #reveal() {
    const range = this.#range

    if (!range) return this.dismiss()

    if (range.collapsed) {
      const link = this.#linkAt(range)
      link ? this.#showLink(link) : this.dismiss()
    } else if (this.#formattable(range)) {
      this.#show(this.formatTarget, range.getBoundingClientRect())
    } else {
      this.dismiss()
    }
  }

  // Only a selection the editor owns end to end: a drag that started in the title, or one
  // in the settings panel, is none of this controller's business.
  get #range() {
    const selection = document.getSelection()
    if (!selection || selection.rangeCount === 0) return null

    const range = selection.getRangeAt(0)
    const content = this.#content

    return content?.contains(range.startContainer) && content.contains(range.endContainer) ? range : null
  }

  // Code has no bold and an image has no italic; both would offer formats that do nothing.
  #formattable(range) {
    return range.toString().trim() !== "" && !this.#elementOf(range.commonAncestorContainer)?.closest(SKIP)
  }

  #linkAt(range) {
    const link = this.#elementOf(range.startContainer)?.closest("a")

    return this.#content?.contains(link) ? link : null
  }

  #showLink(link) {
    const href = link.getAttribute("href") ?? ""
    this.hrefTarget.textContent = this.#shortened(href)
    this.hrefTarget.title = href

    // A link that wraps has one rect per line; the bubble belongs to the line the caret
    // is on, and a caret inside a link is on the first one often enough not to matter.
    this.#show(this.linkTarget, link.getClientRects()[0] ?? link.getBoundingClientRect())
  }

  #show(bubble, rect) {
    for (const other of [ this.formatTarget, this.linkTarget ]) other.hidden = other !== bubble
    this.#place(bubble, rect)
    this.#paintPressed()
  }

  // Absolute inside the canvas body, so the bubble scrolls with the words it belongs to.
  // Above the selection by default; below it when above would be under the chrome — the
  // toolbar's own bottom edge is the measure, so this stays right when the bar changes.
  // Then clamped to the window on all three edges it can leave: a selection on the last
  // visible line would otherwise put a below-placed bubble off screen, and a selection at
  // the measure's edge would put a wide one past the right of a narrow window. The
  // viewport is documentElement.clientWidth/Height, not window.inner*, which counts the
  // scrollbar gutter as room the bubble doesn't have.
  #place(bubble, rect) {
    const host = this.element.getBoundingClientRect()
    const chrome = this.#toolbar?.getBoundingClientRect().bottom ?? 0
    const view = document.documentElement
    const gap = 8

    let top = rect.top - bubble.offsetHeight - gap
    if (top < chrome + gap) top = rect.bottom + gap
    top = Math.max(Math.min(top, view.clientHeight - bubble.offsetHeight - gap), chrome + gap)

    const centred = rect.left + rect.width / 2 - bubble.offsetWidth / 2
    const left = Math.min(Math.max(centred, gap), view.clientWidth - bubble.offsetWidth - gap)

    bubble.style.top = `${top - host.top}px`
    bubble.style.left = `${left - host.left}px`
  }

  #paintPressed() {
    for (const button of this.element.querySelectorAll(".selection-bubble [data-for]")) {
      const pressed = this.#toolbarButton(button.dataset.for)?.getAttribute("aria-pressed")
      pressed ? button.setAttribute("aria-pressed", pressed) : button.removeAttribute("aria-pressed")
    }
  }

  // Three shapes of toolbar button. Most carry a name; the heading buttons Lexxy generates
  // carry the tag instead; Unlink is a value on the link panel's own button, and clicking
  // it dispatches the gem's unlink command with the panel still shut.
  #toolbarButton(name) {
    if (/^h[1-6]$/.test(name)) return this.#toolbar?.querySelector(`.lexxy-heading-button[data-heading="${name}"]`)
    if (name === "unlink") return this.#toolbar?.querySelector("lexxy-link-dropdown [value='unlink']")

    return this.#toolbar?.querySelector(`[name="${name}"]`)
  }

  #elementOf(node) {
    return node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement
  }

  // A URL is read from its ends: the host says whose it is and the last segment says what
  // it points at. The middle is the part nobody checks.
  #shortened(url, limit = 44) {
    if (url.length <= limit) return url

    const half = Math.floor((limit - 1) / 2)
    return `${url.slice(0, half)}…${url.slice(-half)}`
  }

  get #toolbar() {
    return this.element.querySelector("lexxy-toolbar")
  }

  get #content() {
    return this.element.querySelector(".lexxy-editor__content")
  }
}
