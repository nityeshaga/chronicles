import { Extension, ActionTextAttachmentNode, CustomActionTextAttachmentNode } from "lexxy"

// Ghost's kg-* cards are the site's dialect: the importer wrote every card as a bare
// figure/div with kg-* classes, 30 published posts hold them, and the public CSS styles
// exactly that. Lexxy has nodes for paragraphs, headings, lists, quotes, code, links,
// images and attachments — and nothing else. Open an imported post and figure, figcaption,
// div, details and iframe are unwrapped or dropped, every img becomes an attachment whose
// caption is its alt, and the first autosave publishes the wreck (PROBLEMS A1).
//
// This teaches the editor the dialect. A kg-image-card it can carry as its own image node
// (src, alt, caption, size) and export back as an attachment the server renders through
// ImageCardsHelper — so the caption is editable in place. Every other card, and an image
// card with more than the node can hold (srcset, a width class, a link), becomes an opaque
// text/html attachment holding the card's markup verbatim: visible in the canvas, movable,
// deletable, written back untouched.
//
// Twin notice: app/helpers/image_cards_helper.rb paints the public figure this reads.
// The attributes taken from the figure here — img src/alt/width/height, the figcaption —
// are the ones it emits, and test/integration/kg_cards_round_trip_test.rb restates
// isEditableImageCard in Ruby. Change one side, change all three.

// Everything a card may hold that Lexxy's sanitizer would otherwise strip before painting
// an opaque card in the canvas. What the server's allow-list drops anyway (script, button,
// svg, data-*) stays out, so the canvas shows what the page will.
const CARD_ELEMENTS = [
  "figure", "figcaption", "div", "summary", "thead", "tfoot", "caption", "colgroup", "col",
  { tag: "details", attributes: [ "open" ] },
  { tag: "img", attributes: [ "srcset", "sizes", "loading" ] },
  { tag: "a", attributes: [ "target", "rel" ] }
]

// The figure's img may carry exactly what the image node carries back.
const IMAGE_ATTRIBUTES = [ "src", "alt", "width", "height", "class", "loading" ]

export default class KgCards extends Extension {
  get allowedElements() {
    return CARD_ELEMENTS
  }

  // Priority 3 beats the default conversions (img at 1, attachments and galleries at 2),
  // so a card is read whole before Lexical reaches the img inside it. A bare iframe is a
  // Ghost HTML card with no class to match; it would otherwise vanish.
  get lexicalExtension() {
    return this.defineExtension({
      name: "chronicles/kg-cards",
      html: {
        import: {
          figure: importCard,
          div: importCard,
          details: importCard,
          iframe: importCard
        }
      }
    })
  }
}

function importCard(element) {
  if (!element.classList.contains("kg-card") && element.tagName !== "IFRAME") return null

  const node = isEditableImageCard(element) ? imageNodeFor : opaqueNodeFor
  return { conversion: () => ({ node: node(element) }), priority: 3 }
}

function isEditableImageCard(figure) {
  if (!figure.classList.contains("kg-image-card")) return false
  if (Array.from(figure.classList).some(name => name.startsWith("kg-width-"))) return false

  const [ img, caption, ...rest ] = figure.children
  return img?.tagName === "IMG"
    && Array.from(img.attributes).every(attribute => IMAGE_ATTRIBUTES.includes(attribute.name))
    && (!caption || caption.tagName === "FIGCAPTION")
    && rest.length === 0
    && Array.from(figure.childNodes).every(child => child.nodeType !== Node.TEXT_NODE || !child.textContent.trim())
}

function imageNodeFor(figure) {
  const img = figure.querySelector(":scope > img")
  const figcaption = figure.querySelector(":scope > figcaption")
  const src = img.getAttribute("src") || ""

  return new ActionTextAttachmentNode({
    src,
    altText: img.getAttribute("alt") || "",
    caption: figcaption ? captionOf(figcaption) : "",
    contentType: "image/*",
    fileName: src.split("/").pop(),
    width: img.getAttribute("width"),
    height: img.getAttribute("height")
  })
}

// A caption with markup (a photo credit's links, 33 in the archive) keeps it; the server
// renders the caption as HTML. Plain text stays plain so the caption field reads as prose.
function captionOf(figcaption) {
  return figcaption.children.length ? figcaption.innerHTML : figcaption.textContent
}

function opaqueNodeFor(element) {
  return new CustomActionTextAttachmentNode({ contentType: "text/html", innerHtml: element.outerHTML })
}
