# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# The writing room's entry and its controllers. Preloaded only behind that entry point,
# so a public page's <head> never asks the browser to fetch the editor.
pin_all_from "app/javascript/writing", under: "writing", preload: "writing"
pin "lexxy", to: "lexxy.min.js", preload: "writing"
# Lexxy extensions, configured from the writing entry. Embed frames widens the editor-side
# sanitizer so stored embeds aren't painted empty; body headings keeps `# ` from minting h1s.
pin "lexxy_embed_frames", preload: "writing"
# Teaches the editor Ghost's kg-* cards, so imported bodies round-trip.
pin "lexxy_kg_cards", preload: "writing"
pin "lexxy_body_headings", preload: "writing"
# Lexxy dynamically imports this for editor image/file direct uploads.
pin "@rails/activestorage", to: "activestorage.esm.js", preload: "writing"
