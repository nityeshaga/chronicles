# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "lexxy"
# Widens Lexxy's editor-side sanitizer allow-list so stored embeds aren't painted empty.
pin "lexxy_embed_frames"
# Lexxy dynamically imports this for editor image/file direct uploads.
pin "@rails/activestorage", to: "activestorage.esm.js"
