import { Controller } from "@hotwired/stimulus"

// The browser's own copy of one field, kept in localStorage while a save is still owed.
// One slot per record — the key is the markup's, so two open posts can't trade drafts —
// written on every change and cleared only when a save is confirmed (saved), never on
// the attempt: clearing when the save goes out is how a failed save would eat the very
// text this exists to keep.
//
// On connect a slot that differs from what the server rendered is offered, not forced
// in. The writer may have finished the thought in another tab, and only he knows. Restore
// writes the value and re-fires the field's input event, because everything downstream —
// autosave above all — listens to events, not to property writes.
//
// Generic on purpose: a field, a slot, a notice. Which field and which record are the
// view's to say.
export default class extends Controller {
  static targets = ["input", "notice", "age"]
  static values = { key: String }

  async connect() {
    // The field may be a custom element still settling; a frame later its value is real.
    await new Promise(requestAnimationFrame)
    this.#offer()
  }

  save() {
    const value = this.inputTarget.value
    if (value) {
      localStorage.setItem(this.keyValue, JSON.stringify({ value, at: Date.now() }))
    } else {
      this.#clear()
    }
  }

  saved() {
    this.#clear()
  }

  restore() {
    const slot = this.#slot
    if (slot) {
      this.inputTarget.value = slot.value
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.noticeTarget.hidden = true
  }

  discard() {
    this.#clear()
    this.noticeTarget.hidden = true
  }

  #offer() {
    const slot = this.#slot
    if (!slot || slot.value === this.inputTarget.value) return

    this.ageTarget.textContent = relativeTime(slot.at)
    this.noticeTarget.hidden = false
  }

  #clear() {
    localStorage.removeItem(this.keyValue)
  }

  get #slot() {
    try {
      return JSON.parse(localStorage.getItem(this.keyValue))
    } catch {
      return null
    }
  }
}

const UNITS = [["day", 86400], ["hour", 3600], ["minute", 60], ["second", 1]]

function relativeTime(at) {
  const seconds = Math.round((at - Date.now()) / 1000)
  const [unit, size] = UNITS.find(([, size]) => Math.abs(seconds) >= size) || UNITS.at(-1)
  return new Intl.RelativeTimeFormat("en", { numeric: "auto" }).format(Math.round(seconds / size), unit)
}
