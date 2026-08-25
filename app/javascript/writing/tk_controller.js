import { Controller } from "@hotwired/stimulus"

// TK is a writer's note to himself: a fact he hasn't looked up yet, left in the prose so
// the sentence can keep moving. Ghost marks each one in the margin and warns before
// publishing, and this is that — Koenig's own matcher, the title and subtitle counted
// alongside the body, one marker a line, and a note in the publish popover that warns and
// never blocks. Shipping with a TK in it is the writer's call; not being told isn't.
//
// Nothing here writes into the editor. Lexical reconciles every node inside
// .lexxy-editor__content against its own model, so a <span> painted in there is a node it
// did not put there and the next update either discards it or swallows it into the
// document. The markers get their own absolutely-positioned layer over the canvas, and the
// prose is only ever measured.
//
// It rides the shell rather than the canvas because the two things it writes are at
// opposite ends of the page: the gutter on the canvas, and the note in the publish
// popover, which lives outside the form (a nested <form> would be stripped).

// TKPlugin.tsx, ported. TK, Tk or tk, optionally wrapped in punctuation, with no letter or
// digit on either side: "TK", "(TK)" and "TK:" count; "Atkins" and "tks" don't. The Unicode
// property escapes do the word-boundary work \b cannot — \b is ASCII-only, and "naïveTK"
// is not a TK. The neighbouring characters are captured and tested rather than looked
// behind, because Safari before 16.4 has no lookbehind; the em-dash exceptions are Ghost's.
const TK = /(^|.)([^\p{L}\p{N}\s]*(TK|Tk|tk)+[^\p{L}\p{N}\s]*)(.)?/u
const WORD_CHAR = /\p{L}|\p{N}/u
const SCAN_DELAY = 250

export default class extends Controller {
  static targets = [ "title", "subtitle", "body", "gutter", "note", "count" ]

  #timer

  connect() {
    this.scan()
  }

  disconnect() {
    clearTimeout(this.#timer)
  }

  // A scan walks every text node in the body and measures a range per hit, so it waits for
  // a pause the way the save does rather than running per keystroke.
  scan() {
    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => this.#paint(), SCAN_DELAY)
  }

  #paint() {
    const origin = this.gutterTarget.getBoundingClientRect().top
    const tops = []
    let count = 0

    // A textarea has no ranges to measure, so its TKs are marked against the field itself:
    // one mark for a title, however many notes the writer left in it.
    for (const field of [ this.titleTarget, this.subtitleTarget ]) {
      const found = tkRanges(field.value).length
      if (found === 0) continue

      count += found
      tops.push(field.getBoundingClientRect().top - origin)
    }

    for (const node of this.#textNodes) {
      for (const { start, end } of tkRanges(node.data)) {
        count++
        const rect = rangeRect(node, start, end)
        if (rect) tops.push(rect.top - origin)
      }
    }

    this.#draw(tops)
    this.#warn(count)
  }

  // One marker a line. Three TKs in one sentence are one place to go back to, and three
  // pills stacked on the same pixel would read as a rendering fault.
  #draw(tops) {
    const lines = [ ...new Set(tops.map(Math.round)) ].sort((a, b) => a - b)

    this.gutterTarget.replaceChildren(...lines.map(top => {
      const marker = document.createElement("span")
      marker.className = "tk-marker"
      marker.textContent = this.gutterTarget.dataset.label
      marker.style.top = `${top}px`
      return marker
    }))
  }

  // The popover may not exist yet — a post has no publish controls until it is a record.
  #warn(count) {
    if (!this.hasNoteTarget) return

    const { one, many } = this.noteTarget.dataset
    this.noteTarget.hidden = count === 0
    this.countTarget.textContent = `${count} ${count === 1 ? one : many}`
  }

  get #textNodes() {
    const content = this.bodyTarget.querySelector(".lexxy-editor__content")
    if (!content) return []

    const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT)
    const nodes = []
    for (let node = walker.nextNode(); node; node = walker.nextNode()) nodes.push(node)
    return nodes
  }
}

function tkRanges(text) {
  const ranges = []
  let offset = 0

  while (offset < text.length) {
    const found = firstTk(text.slice(offset))
    if (!found) break

    ranges.push({ start: offset + found.start, end: offset + found.end })
    offset += found.end
  }
  return ranges
}

// getTKMatch from TKPlugin.tsx: the regex over-matches because it cannot look behind, so
// invalid hits are discarded one at a time while the text already stepped over is kept —
// that running length is what keeps the offsets true against the original string.
function firstTk(text) {
  let match = TK.exec(text)
  let stepped = ""

  while (match !== null && !isValid(match)) {
    const upto = match.index + match[0].length - 1
    stepped += text.slice(0, upto)
    text = text.slice(upto)
    match = TK.exec(text)
  }
  if (match === null) return null

  const start = stepped.length + match.index + match[1].length
  return { start, end: start + match[2].length }
}

function isValid(match) {
  if (match[1] && match[1].trim() && WORD_CHAR.test(match[1]) && match[2].slice(0, 1) !== "—") return false
  if (match[4] && match[4].trim() && WORD_CHAR.test(match[4]) && match[2].slice(-1) !== "—") return false
  return true
}

function rangeRect(node, start, end) {
  const range = document.createRange()
  range.setStart(node, start)
  range.setEnd(node, end)
  return range.getClientRects()[0]
}
