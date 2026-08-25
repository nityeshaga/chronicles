import { Controller } from "@hotwired/stimulus"

// What the bar says once the canvas has scrolled out from under it: which post this is,
// and how much of it there is. Both are answers the writer already has while the title is
// on screen — the bar only carries them past the fold.
//
// The title is mirrored, never moved: the textarea on the canvas stays the one place a
// title is edited, and the bar shows a copy of what it holds. The copy appears only once
// the real one has gone under the bar, which an IntersectionObserver answers exactly and a
// scroll listener only guesses at.
//
// The count is the server's on first paint — right before any JavaScript runs, and right
// on a post nobody types into — and the browser's from lexxy:initialize on, recounted off
// the visible prose. The words-per-minute rides in as a value, because a 265 typed here
// would be a second copy of the number the published page already prints, free to drift
// from it. The two counts are not identical to the word: Ruby strips the tags, which glues
// one block onto the next, while innerText breaks a line between them. That is why the
// first recount happens at connect rather than at the first keystroke — the correction
// lands while the page is still arriving, not under the writer's hands. It has to be
// connect and not a lexxy:initialize action: the writing entry imports Lexxy before it
// eager-loads these controllers, so the editor has already announced itself by the time
// any data-action here exists to hear it. By the same ordering, the editor is already
// built when this connects, so there is prose to count.
const RECOUNT_DELAY = 300

export default class extends Controller {
  static targets = [ "chrome", "title", "canvasTitle", "count", "words", "wordUnit", "minutes", "body" ]
  static values = { readingSpeed: Number }

  #observer
  #timer

  connect() {
    // Gone means gone under the bar, not gone from the viewport, so the observer's root
    // loses exactly the height the bar is actually standing at — measured off the bar
    // rather than repeated here from the stylesheet.
    this.#observer = new IntersectionObserver(([ entry ]) => {
      this.titleTarget.hidden = entry.isIntersecting
    }, { rootMargin: `-${this.chromeTarget.offsetHeight}px 0px 0px 0px` })
    this.#observer.observe(this.canvasTitleTarget)
    this.retitle()
    this.#recount()
  }

  disconnect() {
    this.#observer?.disconnect()
    clearTimeout(this.#timer)
  }

  retitle() {
    this.titleTarget.textContent = this.canvasTitleTarget.value
  }

  // Recounting on every keystroke would walk the whole body per character. A third of a
  // second is long enough to be free and short enough that the number never reads stale.
  recount() {
    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => this.#recount(), RECOUNT_DELAY)
  }

  #recount() {
    const words = this.#words
    const unit = words === 1 ? this.countTarget.dataset.wordOne : this.countTarget.dataset.wordMany

    this.wordsTarget.textContent = words.toLocaleString(document.documentElement.lang || undefined)
    this.wordUnitTarget.textContent = unit
    this.minutesTarget.textContent = Math.max(Math.ceil(words / this.readingSpeedValue), 1)
  }

  get #words() {
    const text = this.bodyTarget.querySelector(".lexxy-editor__content")?.innerText.trim()
    return text ? text.split(/\s+/).length : 0
  }
}
