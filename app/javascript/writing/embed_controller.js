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
// never answers — is left exactly as Lexxy made it: a plain link, no alert.
const BLOCKS = "p, h1, h2, h3, h4, h5, h6, li, blockquote, td, th"

export default class extends Controller {
  static targets = [ "editor" ]
  static values = { url: String }

  // The slash menu's /embed. The writer typed the URL instead of pasting it, so make the
  // link he would have made and then take the same road: same server, same swap, same
  // undo. Handing the markup straight to the editor would have worked too — it takes the
  // identical route back out of kg-cards — but then a host Embed doesn't know would leave
  // the writer with nothing where his URL was. This way it leaves him a link, exactly as
  // a paste does.
  async insert({ detail: { argument: url } }) {
    if (!url) return

    const linkKey = this.editorTarget.contents.createLink(url)
    const html = await this.#embedHtml(url)

    if (html && this.element.isConnected) {
      this.editorTarget.contents.replaceNodeWithHTML(linkKey, html, { attachment: { contentType: "text/html" } })
    }
  }

  async unfurl({ detail: { url, replaceLinkWith } }) {
    if (!await this.#ownsItsLine(url)) return

    const html = await this.#embedHtml(url)
    // The fetch is long enough for the writer to have navigated away mid-flight.
    if (html && this.element.isConnected) {
      replaceLinkWith(html, { attachment: { contentType: "text/html" } })
    }
  }

  // Lexxy announces the link a frame before Lexical paints it, so wait for the DOM to
  // catch up. Lexical leaves the caret inside the link it just inserted, which is what
  // names the block that link landed in — the URL earns a card only when it's the whole
  // block. Asking the caret rather than matching on href keeps the answer about *this*
  // paste, even when the same URL already appears elsewhere in the post.
  async #ownsItsLine(url) {
    await new Promise(requestAnimationFrame)

    return this.#blockAtCaret()?.textContent.trim() === url
  }

  #blockAtCaret() {
    const caret = document.getSelection()?.anchorNode
    const element = caret?.nodeType === Node.TEXT_NODE ? caret.parentElement : caret
    const block = element?.closest(BLOCKS)

    return this.element.contains(block) ? block : null
  }

  async #embedHtml(url) {
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({ url })
      })

      return response.ok ? await response.text() : null
    } catch {
      return null
    }
  }
}
