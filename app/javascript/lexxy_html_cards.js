import { Extension, CustomActionTextAttachmentNode } from "lexxy"

// An HTML card in the canvas is the real card, not its skeleton. Lexxy paints a content
// attachment by sanitizing the `content` it carries — which for a card is the static
// skeleton the partial renders for mail and feeds, style and script pruned — so a chart
// showed the writer an unstyled table and a bare caption ("they break badly in canvas").
//
// The bytes can't come through the body: Action Text scrubs them on every render, and
// the record carries them for that reason (html_card.rb). So the canvas does what the
// public page does and asks the server, through a URL with a hole in it that the editor
// element carries (data-html-card-url-template, `__sgid__`), filled from the sgid the
// attachment node already holds. The frame is sandboxed with scripts and nothing else:
// no same-origin, so a card's script can't read the writer's session or the post around
// it, and the document says the same of itself in a CSP sandbox header.
//
// The node is Lexxy's own custom-attachment node under another name, claiming only the
// attachments that are cards — a record (an sgid) of type text/html; an embed is
// text/html too but is not a record — and exporting exactly what the base node exports,
// so the stored body is unchanged. Everything that isn't the canvas still gets the
// skeleton.
class HtmlCardNode extends CustomActionTextAttachmentNode {
  static getType() {
    return "html_card"
  }

  static clone(node) {
    return new HtmlCardNode({ ...node }, node.__key)
  }

  static importJSON(serializedNode) {
    return new HtmlCardNode({ ...serializedNode })
  }

  static importDOM() {
    return {
      [this.TAG_NAME]: (element) => {
        if (!this.#isCard(element)) return null

        return {
          conversion: (attachment) => ({ node: new HtmlCardNode(this.#attributesFrom(attachment)) }),
          // Above the base node's 2, so this conversion wins for a card and stays out of
          // the way of everything else.
          priority: 3
        }
      }
    }
  }

  static #isCard(element) {
    return element.getAttribute("sgid") && element.getAttribute("content-type") === "text/html" && element.getAttribute("content")
  }

  // The editor tag helper JSON-encodes `content` on the way in; an inserted card arrives raw.
  static #attributesFrom(attachment) {
    const content = attachment.getAttribute("content")
    let innerHtml
    try { innerHtml = JSON.parse(content) } catch { innerHtml = content }

    return { sgid: attachment.getAttribute("sgid"), contentType: attachment.getAttribute("content-type"), innerHtml }
  }

  // Lexxy's figure — content-type, decorator and drag attributes, the delete button — with
  // the skeleton swapped for the frame. Outside an editor that stamps the template (there
  // is one: the post form), the skeleton stands.
  createDOM(config, editor) {
    const figure = super.createDOM(config, editor)
    const template = editor.getRootElement()?.closest("lexxy-editor")?.dataset.htmlCardUrlTemplate
    if (!template) return figure

    const frame = document.createElement("iframe")
    frame.src = template.replace("__sgid__", encodeURIComponent(this.sgid))
    frame.setAttribute("sandbox", "allow-scripts")
    frame.loading = "lazy"
    frame.title = "HTML card"
    frame.className = "html-card-frame"

    figure.replaceChildren(frame, ...figure.querySelectorAll("lexxy-node-delete-button"))
    return figure
  }

  exportJSON() {
    return { ...super.exportJSON(), type: "html_card" }
  }
}

// Configured by the writing entry (writing/index.js), together with the other extension.
export default class HtmlCards extends Extension {
  // A card's document reports its height (html_cards/show.html.erb). The frame has no
  // origin to check, so the sender is checked instead: only a frame this editor painted —
  // and the number is clamped, so a card can't stretch the page by asking.
  #resize = (event) => {
    const height = Math.min(Math.max(event.data?.htmlCardHeight, 0), 4000)
    if (!Number.isInteger(height)) return

    const frame = Array.from(this.editorElement.querySelectorAll("iframe.html-card-frame"))
      .find(frame => frame.contentWindow === event.source)
    if (frame) frame.style.height = `${height}px`
  }

  constructor(editorElement) {
    super(editorElement)
    addEventListener("message", this.#resize)
  }

  dispose() {
    removeEventListener("message", this.#resize)
  }

  get lexicalExtension() {
    return this.defineExtension({ name: "chronicles/html_cards", nodes: [ HtmlCardNode ] })
  }
}
