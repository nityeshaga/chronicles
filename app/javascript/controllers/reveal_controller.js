import { Controller } from "@hotwired/stimulus"

// Progressive-enhancement reveal: staggers `.rise` elements up into view on scroll.
// Without JS this controller never connects, so `.rise` stays fully visible — the
// hiding only kicks in once we add the `reveal-ready` class here (see application.css).
export default class extends Controller {
  connect() {
    this.element.classList.add("reveal-ready")

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("in")
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: 0.12 })

    this.element.querySelectorAll(".rise").forEach((el, i) => {
      // A small stagger within a section; the hero sets its own order via --d.
      if (!el.style.transitionDelay && !el.style.getPropertyValue("--d")) {
        el.style.transitionDelay = `${(i % 4) * 0.09}s`
      }
      this.observer.observe(el)
    })

    // Above-the-fold chrome (masthead + hero) is on screen at load — reveal it now.
    requestAnimationFrame(() => {
      this.element.querySelectorAll(".masthead-print .rise, .hero .rise").forEach((el) => {
        el.classList.add("in")
      })
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
