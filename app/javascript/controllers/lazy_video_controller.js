import { Controller } from "@hotwired/stimulus"

// A preview loop only fetches its bytes once it is near the viewport, and pauses when it
// leaves. The log carries a dozen of them; without this every visit downloads all twelve.
export default class extends Controller {
  connect() {
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => entry.isIntersecting ? this.play() : this.pause())
    }, { rootMargin: "200px 0px" })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  play() {
    if (!this.element.src) this.element.src = this.element.dataset.src
    this.element.play().catch(() => {})
  }

  pause() {
    if (this.element.src) this.element.pause()
  }
}
