import { Controller } from "@hotwired/stimulus"

// Copies a source element's text. Generic: the connect page's token and the public
// page's code blocks wear the same controller. The button itself is a JS-only
// affordance, so a caller that names a supported class gets it added once the clipboard
// is confirmed to exist — the stylesheet hides the button until then, and a browser
// without the API never shows a control that would do nothing.
export default class extends Controller {
  static targets = ["source", "button"]
  static classes = ["supported"]

  connect() {
    if (this.hasSupportedClass && navigator.clipboard) this.element.classList.add(this.supportedClass)
  }

  async copy() {
    const text = this.sourceTarget.textContent.trim()

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

  flash() {
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied"
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
  }
}
