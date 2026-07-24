import { Controller } from "@hotwired/stimulus"

// Paste a URL, get a card. The controller invents no embed markup: it POSTs the URL
// to the server (the Embed noun owns provider HTML) and drops whatever comes back
// into Lexxy as a content attachment — the same figure the imported embeds render as.
export default class extends Controller {
  static targets = ["url"]
  static values = { url: String }

  async insert() {
    const url = this.urlTarget.value.trim()
    if (!url) return

    const editor = this.element.querySelector("lexxy-editor")
    if (!editor) return

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({ url })
    })

    if (!response.ok) {
      window.alert("That URL isn't a supported embed (tweets and YouTube only).")
      return
    }

    const html = await response.text()
    // Lexxy stores an HTML content attachment as <action-text-attachment
    // content-type="text/html" content="…">, the same canonical Action Text node
    // Trix produced — so it persists and renders publicly identically. Build the
    // element through the DOM so the provider HTML is escaped into the attribute
    // correctly, then hand its markup to the editor's insertHtml (Lexxy re-imports
    // any node carrying a content attribute as that html content attachment).
    const attachment = document.createElement("action-text-attachment")
    attachment.setAttribute("content-type", "text/html")
    attachment.setAttribute("content", html)
    editor.contents.insertHtml(attachment.outerHTML)
    this.urlTarget.value = ""
  }
}
