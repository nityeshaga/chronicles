import { Controller } from "@hotwired/stimulus"

// Lazily load X/Twitter's widgets.js only on posts that contain a
// twitter-tweet blockquote. Blockquotes degrade to text + link without it.
export default class extends Controller {
  connect() {
    if (window.twttr) {
      window.twttr.widgets?.load(this.element)
      return
    }
    if (document.getElementById("twitter-wjs")) return

    const script = document.createElement("script")
    script.id = "twitter-wjs"
    script.src = "https://platform.twitter.com/widgets.js"
    script.async = true
    document.body.appendChild(script)
  }
}
