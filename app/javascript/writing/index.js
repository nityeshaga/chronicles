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

// One configure call for every extension: Lexxy merges arrays by replacement, so a second
// call would silently drop the first's. It defers defining its elements until the current
// call stack drains, so configuring here — right after the import — lands in time.
configure({ global: { extensions: [ EmbedFrames, KgCards, BodyHeadings, InlineCode, HtmlCards, CodeBlocks ] } })

import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("writing", application)
