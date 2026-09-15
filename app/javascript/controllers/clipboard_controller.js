import { Controller } from "@hotwired/stimulus"

// Copies a source element's text. Generic: the connect page's token, the public
// page's code blocks and the log's "Copy prompt" doors wear the same controller. The
// button itself is a JS-only affordance, so a caller that names a supported class gets
// it added once the clipboard is confirmed to exist — the stylesheet hides the button
// until then, and a browser without the API never shows a control that would do nothing.
// What the button says once copied, for how long, and which class it wears meanwhile
// are the caller's to set; the defaults are the plain "Copied" the writer's room uses.
export default class extends Controller {
  static targets = ["source", "button"]
  static classes = ["supported", "done"]
  static values = {
    copied: { type: String, default: "Copied" },
    duration: { type: Number, default: 2000 }
  }

  connect() {
    if (this.hasSupportedClass && navigator.clipboard) this.element.classList.add(this.supportedClass)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  // Only the trailing newline goes: a code block's first line may be indented on purpose.
  async copy() {
    const text = this.sourceTarget.textContent.replace(/\n$/, "")

    try {
      await navigator.clipboard.writeText(text)
    } catch {
      this.fallbackCopy(text)
    }

    this.flash()
  }

  fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    textarea.remove()
  }

  // The button's own markup comes back afterwards (a door carries an icon), so the
  // original is captured once — a second click mid-flash mustn't save the flash itself.
  flash() {
    this.original ??= this.buttonTarget.innerHTML
    this.buttonTarget.textContent = this.copiedValue
    if (this.hasDoneClass) this.buttonTarget.classList.add(this.doneClass)
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.buttonTarget.innerHTML = this.original
      if (this.hasDoneClass) this.buttonTarget.classList.remove(this.doneClass)
    }, this.durationValue)
  }
}
