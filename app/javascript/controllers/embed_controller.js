import { Controller } from "@hotwired/stimulus"

// Paste a tweet or YouTube URL on its own line and it becomes a card. Lexxy already
// turns a pasted bare URL into a link and announces it with `lexxy:insert-link`, so we
// ride that rather than intercepting `paste`: the link is a real edit before we touch
// it, which is what keeps Cmd+Z honest — one undo puts the URL back. The controller
// invents no embed markup and keeps no list of supported hosts; it asks the server (the
// Embed noun owns both) and hands the answer to Lexxy, which wraps it in the same
// text/html content attachment the imported embeds already render as.
//
// Everything else — a URL dropped mid-sentence, a host Embed doesn't know, a server that
// says no — is left exactly as Lexxy made it: a plain link, no alert.
export default class extends Controller {
  static values = { url: String }

  async unfurl({ detail: { url, replaceLinkWith } }) {
    if (!await this.#ownsItsLine(url)) return

    const html = await this.#embedHtml(url)
    if (html) replaceLinkWith(html, { attachment: { contentType: "text/html" } })
  }

  // Lexxy announces the link a frame before Lexical paints it, so wait for the DOM to
  // catch up. The newest anchor carrying the URL is the one just inserted, and it earns
  // a card only when its block holds nothing but the URL.
  async #ownsItsLine(url) {
    await new Promise(requestAnimationFrame)

    const anchors = [ ...this.element.querySelectorAll("lexxy-editor a") ]
      .filter((anchor) => anchor.getAttribute("href") === url)

    return anchors.at(-1)?.parentElement?.textContent.trim() === url
  }

  async #embedHtml(url) {
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({ url })
    })

    return response.ok ? response.text() : null
  }
}
