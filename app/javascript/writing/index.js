// The writing room's entry: everything the public site loads, plus the editor and the
// controllers only the author's pages wear. Readers never import this module, which is
// what keeps Lexxy off every public page.
import "application"
import { configure } from "lexxy"
import EmbedFrames from "lexxy_embed_frames"
import KgCards from "lexxy_kg_cards"
import BodyHeadings from "lexxy_body_headings"
import InlineCode from "lexxy_inline_code"
import HtmlCards from "lexxy_html_cards"
import CodeBlocks from "lexxy_code_blocks"
import HeadingHotkeys from "lexxy_heading_hotkeys"

// One configure call for every extension: Lexxy merges arrays by replacement, so a second
// call would silently drop the first's. It defers defining its elements until the current
// call stack drains, so configuring here — right after the import — lands in time.
configure({ global: { extensions: [ EmbedFrames, KgCards, BodyHeadings, InlineCode, HtmlCards, CodeBlocks, HeadingHotkeys ] } })

import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("writing", application)

// Custom elements upgrade parent before child, and a Turbo visit inserts the new body as a
// single subtree — so <lexxy-editor> runs its connectedCallback and hands itself to a
// <lexxy-toolbar> that is still an unknown element, throws on setEditor, and leaves Lexical
// unmounted: an editor that looks right, takes keystrokes and drops all of them. A page load
// never shows it, because Lexxy defines lexxy-toolbar before lexxy-editor for exactly this
// reason, and definition order is upgrade order for elements already in the document. So do
// here what the document does there, and upgrade the toolbar before the body goes in: that
// runs its constructor and nothing else, leaving connectedCallback to the insertion.
//
// Adopted first because the upgrade doesn't take otherwise. Turbo parses the response with
// DOMParser, and that document has no browsing context, so the definition lookup a detached
// element does finds nothing and customElements.upgrade returns having done nothing at all.
// Turbo adopts this body a moment later when it swaps it in; the line below only moves that
// step ahead of the upgrade. The toolbars alone, not customElements.upgrade(newBody): the
// whole-body call is no simpler once the adoption is written down, and it would construct
// every custom element on the page early to settle the one pair that has an ordering
// dependency.
addEventListener("turbo:before-render", ({ detail: { newBody } }) => {
  document.adoptNode(newBody)
  newBody.querySelectorAll("lexxy-toolbar").forEach((toolbar) => customElements.upgrade(toolbar))
})
