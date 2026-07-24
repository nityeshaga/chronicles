import { Controller } from "@hotwired/stimulus"

// Suggest a slug from the title, but only while the slug field is untouched. The
// moment the writer edits the slug (or it arrived pre-filled), we back off — the
// field's own state is the source of truth, not a JS flag we have to keep in sync.
export default class extends Controller {
  static targets = ["source", "slug"]

  connect() {
    this.auto = this.slugTarget.value.trim() === ""
  }

  edited() {
    this.auto = false
  }

  suggest() {
    if (this.auto) this.slugTarget.value = this.#slugify(this.sourceTarget.value)
  }

  #slugify(value) {
    return value
      .toString()
      .toLowerCase()
      .trim()
      .replace(/[^\w\s-]/g, "")
      .replace(/[\s_]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "")
  }
}
