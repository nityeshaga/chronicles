import { Controller } from "@hotwired/stimulus"

// The margin of a doc: comments parked beside the passage each was left on, the passage
// itself tinted, and a button that a selection raises to start a new one.
//
// Nothing here writes into the editor, for the reason tk gives: Lexical reconciles every
// node inside .lexxy-editor__content against its own model. So a comment is pinned to
// words rather than to a node — its quote, and the few characters before it — and found
// again by reading the prose. The tint is a CSS highlight, which paints a Range without
// touching the tree, and a card is positioned by measuring that same Range.
//
// The server draws every card (comments#index, into the frame); this controller only
// places them. That is also the whole of "live": the frame is asked again every so often,
// and a comment the agent left over MCP arrives as the same HTML a local one would.
//
// It rides the shell because what it reads and what it places are on opposite sides of
// the form boundary: the prose is inside the editor's form, and comments are forms.

const REMEASURE_DELAY = 200
const SELECTION_DELAY = 150
const POLL_INTERVAL = 20_000
const GAP = 10
const PREFIX_LENGTH = 32
// What the highlight can be asked to find again. A longer selection is pinned by how it
// opens, which is still exactly one place in the prose.
const QUOTE_LIMIT = 400
const WIDE = "(min-width: 1140px)"

const BLOCKS = new Set([ "P", "DIV", "LI", "UL", "OL", "H1", "H2", "H3", "H4", "H5", "H6", "BLOCKQUOTE", "PRE", "TABLE", "TR", "TD", "TH", "FIGURE", "FIGCAPTION", "HR", "BR" ])
const INVISIBLE = /[​‌‍⁠﻿]/

export default class extends Controller {
  static targets = [ "rail", "frame", "thread", "add", "composer", "composerQuote", "composerBody", "quoteField", "prefixField" ]

  // The selection a comment would be about, held from the moment it settles: by the time
  // the button is pressed or the composer is typed in, the live selection is gone.
  #pending = null
  #ranges = new Map()
  #warm = null
  #remeasureTimer
  #selectionTimer
  #pollTimer
  #observer

  connect() {
    this.#observer = new ResizeObserver(() => this.remeasure())
    this.#pollTimer = setInterval(() => this.refresh(), POLL_INTERVAL)
    document.fonts?.ready.then(() => this.remeasure())
    this.remeasure()
  }

  disconnect() {
    clearTimeout(this.#remeasureTimer)
    clearTimeout(this.#selectionTimer)
    clearInterval(this.#pollTimer)
    this.#observer.disconnect()
    this.#clearHighlights()
  }

  // A snapshot is a photograph of a layout: card positions measured against prose that
  // will be laid out again on restore. Drop what was measured; connect() measures afresh.
  beforeCache() {
    this.cancel()
    this.#clearHighlights()
    this.threadTargets.forEach(card => card.style.removeProperty("top"))
  }

  // A card arriving or leaving — the frame redrawn, a thread resolved — moves every card
  // below it, and a card growing (a reply typed, a quote revealed) does the same.
  threadTargetConnected(card) {
    this.#observer?.observe(card)
    this.remeasure()
  }

  threadTargetDisconnected(card) {
    this.#observer?.unobserve(card)
    this.remeasure()
  }

  // The prose moved, or the window did. Waits for a pause, like the save and the TK scan:
  // a measure walks every text node in the body.
  remeasure() {
    clearTimeout(this.#remeasureTimer)
    this.#remeasureTimer = setTimeout(() => this.#measure(), REMEASURE_DELAY)
  }

  // selectionchange is the only driver, because it is the only event every platform sends
  // for every way of selecting — a long-press on a phone never delivers a mouseup.
  selected() {
    clearTimeout(this.#selectionTimer)
    this.#selectionTimer = setTimeout(() => this.#readSelection(), SELECTION_DELAY)
  }

  // The button, and ⌘⌥M. Bound to pointerdown on the button: that lands before the press
  // collapses the selection it is about.
  compose() {
    if (!this.#pending || !this.hasComposerTarget) return

    const { quote, prefix, top } = this.#pending
    this.quoteFieldTarget.value = quote
    this.prefixFieldTarget.value = prefix
    this.composerQuoteTarget.textContent = quote
    this.composerTarget.hidden = false
    this.composerTarget.style.top = `${top}px`
    this.addTarget.hidden = true
    this.#paint("doc-comment-pending", [ this.#pending.range ])
    this.#measure()
    this.composerBodyTarget.focus({ preventScroll: true })
    this.composerTarget.scrollIntoView({ block: "nearest" })
  }

  // ⌘↵ in any comment box sends that box's form.
  send(event) {
    event.preventDefault()
    event.target.form.requestSubmit()
  }

  // The composer's submit came back. The frame it targeted has the new thread in it; what
  // is left to do is put the composer away.
  composed(event) {
    if (event.detail.success) this.cancel()
  }

  cancel() {
    if (!this.hasComposerTarget || this.composerTarget.hidden) return

    this.composerTarget.reset()
    this.composerTarget.hidden = true
    this.#pending = null
    this.#paint("doc-comment-pending", [])
    this.#measure()
  }

  // Pointing at a card lights the passage it is about, and the other way round is the
  // caret: put it inside a commented passage and that card steps forward.
  warm(event) {
    this.#activate(event.currentTarget)
  }

  cool() {
    this.#activate(null)
  }

  // The pill in the corner of a phone: down to the threads, without a navigation.
  toThreads() {
    this.frameTarget.scrollIntoView({ behavior: "instant", block: "start" })
  }

  // A click on a thread — the card itself, not a button or a box inside it — brings its
  // passage into view. On a phone that is the only way from a comment back to its words.
  reveal(event) {
    if (event.target.closest("button, a, textarea, input, summary")) return

    const range = this.#ranges.get(event.currentTarget)
    if (!range) return

    const rect = range.getBoundingClientRect()
    if (rect.top < 120 || rect.bottom > window.innerHeight - 40) {
      // Instant: on a phone the passage can be a dozen screens away, and an animated
      // scroll that long is a wait, not a transition.
      window.scrollBy({ top: rect.top - window.innerHeight / 3, behavior: "instant" })
    }
    this.#activate(event.currentTarget)
  }

  // --- measuring -------------------------------------------------------------------

  #measure() {
    if (!this.hasRailTarget) return

    const content = this.#content
    const text = content ? readProse(content) : null
    const origin = this.railTarget.getBoundingClientRect().top
    const wide = window.matchMedia(WIDE).matches
    const anchored = []
    const orphaned = []

    this.#ranges.clear()
    for (const card of this.threadTargets) {
      const range = text && locate(text, card.dataset.quote, card.dataset.prefix)

      // A thread left on no passage at all (the agent's, about the whole doc) is not an
      // orphan: it never had words to lose. It sits with them at the foot all the same.
      card.toggleAttribute("data-orphaned", !range && Boolean(card.dataset.quote))
      if (range) {
        this.#ranges.set(card, range)
        anchored.push({ card, top: range.getBoundingClientRect().top - origin })
      } else {
        orphaned.push(card)
      }
    }

    this.#paint("doc-comment", [ ...this.#ranges.values() ])

    // On a narrow screen there is no margin: the rail is a list under the prose, in the
    // order the passages come, and nothing is positioned.
    if (!wide) {
      this.threadTargets.forEach(card => card.style.removeProperty("top"))
      anchored.sort((a, b) => a.top - b.top).forEach(({ card }, index) => card.style.order = index)
      orphaned.forEach(card => card.style.order = anchored.length)
      this.element.style.removeProperty("--rail-height")
      return
    }

    // The composer is one more card in the column, parked where its selection is.
    const column = anchored.map(({ card, top }) => ({ card, top }))
    if (this.hasComposerTarget && !this.composerTarget.hidden && this.#pending) {
      column.push({ card: this.composerTarget, top: this.#pending.top - 0.5 })
    }
    column.sort((a, b) => a.top - b.top)

    // Each card as near its passage as the card above allows, and none above the prose:
    // a thread with no passage left starts where the writing does, clear of the bar.
    let cursor = content ? content.getBoundingClientRect().top - origin : 0
    for (const { card, top } of column) {
      const y = Math.max(top, cursor)
      card.style.top = `${y}px`
      cursor = y + card.offsetHeight + GAP
    }
    // Then the threads whose words are gone, and the folded resolved ones, in a row below.
    for (const card of orphaned) {
      card.style.top = `${cursor}px`
      cursor += card.offsetHeight + GAP
    }
    this.frameTarget.style.setProperty("--threads-end", `${cursor}px`)

    // The rail is out of the flow, so the page has to be told how tall it made itself.
    const resolved = this.frameTarget.querySelector(".doc-rail__resolved, .doc-rail__blank")
    const end = cursor + (resolved ? resolved.offsetHeight + GAP : 0)
    this.element.style.setProperty("--rail-height", `${origin - this.element.getBoundingClientRect().top + end + 40}px`)
  }

  #readSelection() {
    if (!this.hasAddTarget) return

    const selection = document.getSelection()
    const content = this.#content
    const usable = content && selection.rangeCount > 0 && !selection.isCollapsed &&
      content.contains(selection.anchorNode) && content.contains(selection.focusNode)

    if (!usable) {
      // A caret inside a commented passage brings its card forward; anywhere else, nothing.
      if (content && selection.rangeCount > 0 && selection.isCollapsed && content.contains(selection.anchorNode)) {
        this.#activate(this.#threadAt(selection.anchorNode, selection.anchorOffset))
      }
      // The composer keeps what it was opened about; only the unpressed button goes.
      if (!this.hasComposerTarget || this.composerTarget.hidden) this.#pending = null
      this.addTarget.hidden = true
      return
    }

    const range = selection.getRangeAt(0)
    const pinned = pin(readProse(content), range)
    if (!pinned) return

    const top = range.getBoundingClientRect().top - this.railTarget.getBoundingClientRect().top
    if (this.hasComposerTarget && !this.composerTarget.hidden) return

    this.#pending = { ...pinned, top, range: range.cloneRange() }
    this.addTarget.style.top = `${top}px`
    this.addTarget.hidden = false
  }

  #threadAt(node, offset) {
    for (const [ card, range ] of this.#ranges) {
      if (range.isPointInRange(node, offset)) return card
    }
    return null
  }

  #activate(card) {
    if (this.#warm === card) return

    this.#warm?.classList.remove("is-warm")
    this.#warm = card
    card?.classList.add("is-warm")
    this.#paint("doc-comment-warm", card && this.#ranges.has(card) ? [ this.#ranges.get(card) ] : [])
  }

  // Asks the server for the margin again: every so often, and the moment the writer comes
  // back to the tab — which is when he has just been told there is a reply waiting. Never
  // while he is in the middle of saying something in it; a redraw would take his words.
  refresh() {
    if (!this.hasFrameTarget || document.hidden) return
    if (this.railTarget.contains(document.activeElement)) return
    if ([ ...this.railTarget.querySelectorAll("textarea") ].some(box => box.value.trim())) return

    const url = this.railTarget.dataset.commentsUrlValue
    if (this.frameTarget.getAttribute("src")) {
      this.frameTarget.reload()
    } else {
      this.frameTarget.src = url
    }
  }

  // --- painting --------------------------------------------------------------------

  // CSS highlights paint ranges without a node being added, which is the only kind of
  // paint Lexical's content element can take. Where the API is missing the cards still
  // sit beside their passages; only the tint is lost.
  #paint(name, ranges) {
    if (!window.CSS?.highlights) return

    if (ranges.length) {
      CSS.highlights.set(name, new Highlight(...ranges))
    } else {
      CSS.highlights.delete(name)
    }
  }

  #clearHighlights() {
    for (const name of [ "doc-comment", "doc-comment-warm", "doc-comment-pending" ]) this.#paint(name, [])
  }

  get #content() {
    return this.element.querySelector(".editor-canvas__body .lexxy-editor__content")
  }
}

// The prose as one line of text, with a map from each character back to the node it came
// from. Whitespace runs collapse to a single space and a block boundary counts as one, so
// "end of a paragraph" + "start of the next" reads the way the model's plain text does —
// which is what lets a quote written by the agent be found the same way as one selected
// here.
function readProse(content) {
  const chars = []
  const map = []
  let pendingBreak = false

  const push = (char, node, offset) => {
    chars.push(char)
    map.push(node ? [ node, offset ] : null)
  }

  const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT)
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    if (node.nodeType === Node.ELEMENT_NODE) {
      if (BLOCKS.has(node.tagName)) pendingBreak = true
      continue
    }

    const data = node.data
    for (let offset = 0; offset < data.length; offset++) {
      const char = data[offset]
      if (INVISIBLE.test(char)) continue

      if (/\s/.test(char)) {
        if (chars.length && chars[chars.length - 1] !== " ") push(" ", node, offset)
        pendingBreak = false
      } else {
        if (pendingBreak && chars.length && chars[chars.length - 1] !== " ") push(" ", null, 0)
        pendingBreak = false
        push(char, node, offset)
      }
    }
  }

  return { chars: chars.join(""), map }
}

// Where a comment's words are now. The prefix settles which occurrence; when the words
// before it have been edited, the quote alone is still worth finding.
function locate(text, quote, prefix = "") {
  if (!quote) return null

  const needle = quote.slice(0, QUOTE_LIMIT)
  let start = -1
  if (prefix) {
    const at = text.chars.indexOf(prefix + needle)
    if (at !== -1) start = at + prefix.length
  }
  if (start === -1) start = text.chars.indexOf(needle)
  if (start === -1) return null

  return rangeOver(text, start, start + needle.length)
}

function rangeOver(text, start, end) {
  // A character the walker invented (a block boundary's space) has no node to point at.
  while (start < end && !text.map[start]) start++
  while (end > start && !text.map[end - 1]) end--
  if (start >= end) return null

  const range = document.createRange()
  const [ first, firstOffset ] = text.map[start]
  const [ last, lastOffset ] = text.map[end - 1]
  range.setStart(first, firstOffset)
  range.setEnd(last, lastOffset + 1)
  return range
}

// A selection, as the two strings that will find it again.
function pin(text, range) {
  let start = indexOf(text, range.startContainer, range.startOffset)
  let end = indexOf(text, range.endContainer, range.endOffset)
  while (start < end && text.chars[start] === " ") start++
  while (end > start && text.chars[end - 1] === " ") end--
  if (start >= end) return null

  return {
    quote: text.chars.slice(start, Math.min(end, start + QUOTE_LIMIT)),
    prefix: text.chars.slice(Math.max(0, start - PREFIX_LENGTH), start)
  }
}

// The first character at or after a point in the document: a binary search, since the map
// is in document order.
function indexOf(text, container, offset) {
  const point = document.createRange()
  point.setStart(container, offset)
  point.collapse(true)

  const probe = document.createRange()
  let low = 0
  let high = text.map.length
  while (low < high) {
    const middle = (low + high) >> 1
    const entry = nearestReal(text.map, middle)
    if (!entry) { high = middle; continue }

    probe.setStart(entry[0], entry[1])
    probe.collapse(true)
    if (probe.compareBoundaryPoints(Range.START_TO_START, point) < 0) {
      low = middle + 1
    } else {
      high = middle
    }
  }
  return low
}

function nearestReal(map, index) {
  for (let i = index; i < map.length; i++) {
    if (map[i]) return map[i]
  }
  return null
}
