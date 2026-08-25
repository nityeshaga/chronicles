import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

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
