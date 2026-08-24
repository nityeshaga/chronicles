import { Controller } from "@hotwired/stimulus"

// Drop hand-authored markup into the body as an HtmlCard — the one thing in a post that
// reaches the reader unsanitized. The markup is the writer's own, but the body never
// carries it: it carries a reference to the record, and only the server can mint one, so
// this asks for the attachment element the way the embed controller asks for provider
// HTML. The client invents no markup here either.
//
// What comes back from an insert is Lexxy's own preview of the card — the static
// skeleton, cleaned, with a delete button, nothing running. That's the editor's terms and
// they're the right ones: the desk is for writing, and a card is only itself once
// published.
export default class extends Controller {
  static targets = [ "editor", "source", "disclosure" ]
  static values = { url: String }

  async insert() {
    const content = this.sourceTarget.value.trim()
    if (!content) return

    const attachment = await this.#attachmentFor(content)
    // The round trip is long enough for the writer to have navigated away mid-flight.
    if (!attachment || !this.element.isConnected) return

    this.editorTarget.contents.insertHtml(attachment)
    this.sourceTarget.value = ""
    this.disclosureTarget.open = false
  }

  // The form treats every keystroke inside it as prose worth saving. What's in the
  // textarea isn't the post until it's inserted, so it doesn't get to mark it unsaved.
  keepOutOfAutosave(event) {
    event.stopPropagation()
  }

  // A refusal leaves the markup where the writer typed it, disclosure still open, rather
  // than swallowing work in exchange for an alert.
  async #attachmentFor(content) {
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({ content })
      })

      return response.ok ? await response.text() : null
    } catch {
      return null
    }
  }
}
