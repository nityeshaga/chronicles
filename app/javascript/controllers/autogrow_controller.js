import { Controller } from "@hotwired/stimulus"

// A single-line-looking textarea that grows with its content — used for the title and
// subtitle so long headlines wrap into the canvas instead of hard-clipping in a one-line
// input. Reset to auto before measuring so the field can shrink as well as grow.
export default class extends Controller {
  connect() {
    // These fields hold single-line values (title/excerpt), so Enter must not mint a
    // literal newline; and a window resize rewraps the text, so re-measure or the
    // overflow:hidden field clips until the next keystroke.
    this.element.addEventListener("keydown", this.blockEnter)
    window.addEventListener("resize", this.grow)
    this.grow()
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.blockEnter)
    window.removeEventListener("resize", this.grow)
  }

  grow = () => {
    this.element.style.height = "auto"
    this.element.style.height = `${this.element.scrollHeight}px`
  }

  blockEnter = (event) => {
    if (event.key === "Enter") event.preventDefault()
  }
}
