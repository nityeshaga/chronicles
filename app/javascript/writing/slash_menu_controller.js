import { Controller } from "@hotwired/stimulus"
import { Lexical } from "lexxy"

// The block menu behind "/". Ghost's trigger rule, exactly: the slash must be the first
// character of an otherwise empty top-level paragraph, with the caret at its end — so
// "and/or" mid-sentence, or a slash inside a list item or a quote, is a slash and
// nothing else.
//
// Lexxy ships <lexxy-prompt>, which looks like this menu and cannot be it: a prompt
// inserts HTML *at the caret*, so a quote or a heading lands nested inside the paragraph
// being typed (<p><blockquote>…</blockquote></p>). This menu inserts nothing. It empties
// the paragraph the "/" was typed in and then clicks a toolbar button, which is the same
// path the toolbar's own hotkeys take — so the commands stay in the one place they live,
// and the block is made where the paragraph was, at the top level.
//
// The controller knows no block names, no routes and no editor internals beyond Lexical's
// selection: the rows in _slash_menu.html.erb say which button they mean, or which event
// to dispatch for the two jobs the toolbar doesn't do.
const HEADING = /^h[1-6]$/
const GAP = 6

export default class extends Controller {
  static targets = [ "editor", "menu", "item" ]

  // The block the writer dismissed with Escape. Kept so the next keystroke inside it
  // doesn't reopen what he just closed; forgotten the moment the caret is elsewhere.
  #dismissed = null
  #block = null
  #argument = ""

  // A row is announced by id, not by text, so the ids are plumbing rather than copy and
  // are stamped here — hand-numbered rows in the partial would drift the first time
  // someone reorders the menu.
  connect() {
    this.itemTargets.forEach((item, index) => item.id ||= `slash-menu-${index}`)
  }

  // Two events ask the same question. `lexxy:change` catches the typing; it fires only
  // when the body's HTML changed, so it can't see a caret arrowing out of the block —
  // `selectionchange` is what closes the menu when the writer walks away from it.
  sync() {
    const block = this.#slashBlock()

    if (!block) {
      this.#dismissed = null
      return this.#hide()
    }
    if (block === this.#dismissed) return this.#hide()

    this.#open(block)
  }

  close() {
    this.#hide()
  }

  // Arrows, Enter and Escape belong to the menu while it's open, and Lexical's own root
  // listener sits on the contenteditable below this element — so this runs in the capture
  // phase, where it can answer them before the editor ever sees them.
  navigate(event) {
    if (!this.#showing) return

    switch (event.key) {
      case "ArrowDown": this.#move(1); break
      case "ArrowUp": this.#move(-1); break
      case "Enter": this.#run(this.#selected); break
      case "Escape": this.#dismissed = this.#block; this.#hide(); break
      default: return
    }

    event.preventDefault()
    event.stopPropagation()
  }

  pick(event) {
    this.#run(event.target.closest("[role=option]"))
  }

  // A click in the menu must not take the caret out of the paragraph the command is
  // about to rewrite.
  keepSelection(event) {
    event.preventDefault()
  }

  #open(block) {
    const { query, argument } = this.#parse(block)
    const matches = this.itemTargets.filter(item => this.#matches(item, query))

    for (const item of this.itemTargets) item.hidden = !matches.includes(item)
    if (matches.length === 0) return this.#hide()

    this.#block = block
    this.#argument = argument
    if (!matches.includes(this.#selected)) this.#select(matches[0])

    this.menuTarget.hidden = false
    this.#place(block)
  }

  #hide() {
    this.menuTarget.hidden = true
    this.#content?.removeAttribute("aria-activedescendant")
    this.#block = null
  }

  // A row that says it needs the words after the trigger does nothing without them: the
  // menu stays open on "/embed" and the writer types the link. Which rows those are is
  // the markup's to say.
  #run(item) {
    if (!item) return

    const { for: name, dispatch: event } = item.dataset
    const argument = this.#argument
    if (item.hasAttribute("data-requires-argument") && argument === "") return

    this.#hide()
    this.#emptyBlock()

    // Branch on what the row claims, not on what the lookup found: a row naming a button
    // that has gone missing must fail quietly, not dispatch an event named "undefined"
    // after the line has already been emptied.
    name ? this.#toolbarButton(name)?.click() : this.dispatch(event, { detail: { argument } })
  }

  // The "/quote" the writer typed was never the post — it was how he asked for one. Empty
  // the paragraph through Lexical (never the DOM, which the editor owns) and leave the
  // caret in it, so the command that runs next transforms an empty block.
  #emptyBlock() {
    this.editorTarget.editor.update(() => {
      const selection = Lexical.$getSelection()
      if (!Lexical.$isRangeSelection(selection)) return

      const block = selection.anchor.getNode().getTopLevelElement()
      block?.clear()
      block?.selectEnd()
    })
  }

  #toolbarButton(name) {
    if (!name) return null

    return this.#toolbar?.querySelector(
      HEADING.test(name) ? `.lexxy-heading-button[data-heading="${name}"]` : `[name="${name}"]`
    )
  }

  // The filter is the word after the "/", up to the first space; whatever follows the
  // space is the row's argument (the URL /embed wants).
  #parse(block) {
    const [ , query, argument ] = block.textContent.match(/^\/(\S*)\s*([\s\S]*)$/)

    return { query: query.toLowerCase(), argument: argument.trim() }
  }

  #matches(item, query) {
    return query === "" || item.dataset.keywords.split(/\s+/).some(word => word.startsWith(query))
  }

  #slashBlock() {
    const selection = document.getSelection()
    if (!selection?.isCollapsed) return null

    const block = this.#topLevelParagraphAt(selection.focusNode)
    if (!block?.textContent.startsWith("/")) return null

    return this.#caretEnds(block, selection) ? block : null
  }

  #topLevelParagraphAt(node) {
    const element = node?.nodeType === Node.TEXT_NODE ? node.parentElement : node
    const block = element?.closest("p")

    return block?.parentElement === this.#content ? block : null
  }

  #caretEnds(block, selection) {
    const rest = document.createRange()
    rest.setStart(selection.focusNode, selection.focusOffset)
    rest.setEnd(block, block.childNodes.length)

    return rest.toString() === ""
  }

  // Which row is current is the aria-selected attribute and nothing else — the highlight
  // and what a screen reader announces read the same fact, so they can't drift. Focus
  // never leaves the prose, so the editor's root is what points at the row: an attribute
  // on the contenteditable itself, which Lexical leaves alone (it reconciles children).
  #select(item) {
    for (const other of this.itemTargets) other.setAttribute("aria-selected", other === item)
    this.#content?.setAttribute("aria-activedescendant", item.id)
    item.scrollIntoView({ block: "nearest" })
  }

  #move(step) {
    const items = this.#visibleItems
    const next = (items.indexOf(this.#selected) + step + items.length) % items.length
    this.#select(items[next])
  }

  // Under the paragraph the "/" sits in — the slash is always at the start of a line, so
  // the measure's left edge is the menu's. It flips above only when the page is out of
  // room below *and* has more of it above; on a short window both sides are short, and
  // flipping into the smaller one just moves the clipping to the top of the screen.
  #place(block) {
    const line = block.getBoundingClientRect()
    const canvas = this.element.getBoundingClientRect()
    const menu = this.menuTarget
    const below = window.innerHeight - line.bottom - GAP
    const above = line.top - GAP

    menu.style.left = `${line.left - canvas.left}px`
    menu.style.top = below < menu.offsetHeight && above > below
      ? `${line.top - canvas.top - menu.offsetHeight - GAP}px`
      : `${line.bottom - canvas.top + GAP}px`
  }

  get #showing() {
    return !this.menuTarget.hidden
  }

  get #selected() {
    return this.itemTargets.find(item => item.getAttribute("aria-selected") === "true")
  }

  get #visibleItems() {
    return this.itemTargets.filter(item => !item.hidden)
  }

  get #toolbar() {
    return this.editorTarget.querySelector("lexxy-toolbar")
  }

  get #content() {
    return this.editorTarget.querySelector(".lexxy-editor__content")
  }
}
