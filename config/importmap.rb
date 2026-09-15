# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# The preview strip's controller, registered by the preview page alone: it renders in the
# public layout, so it can't ride the writing entry, and it mustn't ride the public one.
pin "preview", preload: false

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
# Adds the one toolbar command Lexxy lacks: toggling inline code.
pin "lexxy_inline_code", preload: "writing"
# Paints an HTML card in the canvas as the real thing, framed, instead of its skeleton.
pin "lexxy_html_cards", preload: "writing"
# A new code block is plain text, and a pasted fence or class keeps its language.
pin "lexxy_code_blocks", preload: "writing"
# ⌘⌥2/3/4/0 for headings — matched on event.code, which data-hotkey can't do.
pin "lexxy_heading_hotkeys", preload: "writing"
# Lexxy dynamically imports this for editor image/file direct uploads.
pin "@rails/activestorage", to: "activestorage.esm.js", preload: "writing"
