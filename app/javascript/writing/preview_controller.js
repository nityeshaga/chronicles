import { Controller } from "@hotwired/stimulus"

// The preview strip's one trick: Phone shows this same page in a 390px window. The
// site's responsive rules are viewport media queries, so the only honest phone view is a
// real viewport that wide — an iframe of the page itself, loaded on first click and never
// before, so a preview the writer reads at desktop width costs one render, not two. The
// copy inside the frame carries a strip of its own and drops it, because a banner inside
// the phone would be the one thing the phone will never show.
//
// Which width is showing lives on <html> (so CSS can swap the page for the frame) and on
// the buttons (aria-pressed), nowhere in JS state.
export default class extends Controller {
  static targets = [ "frame", "desktop", "phone" ]
  static classes = [ "phone" ]

  connect() {
    if (window.frameElement) this.element.remove()
  }

  desktop() {
    document.documentElement.classList.remove(this.phoneClass)
    this.#press(this.desktopTarget)
  }

  phone() {
    this.frameTarget.src ||= location.href
    document.documentElement.classList.add(this.phoneClass)
    this.#press(this.phoneTarget)
  }

  // Turbo caches the page as it stands; a cached phone view would paint a dark backdrop
  // under the next page for a frame the snapshot can't run.
  reset() {
    this.desktop()
  }

  #press(button) {
    for (const other of [ this.desktopTarget, this.phoneTarget ]) {
      other.setAttribute("aria-pressed", other === button)
    }
  }
}
