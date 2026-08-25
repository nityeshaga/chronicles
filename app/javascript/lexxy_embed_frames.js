import { Extension, configure } from "lexxy"

// Lexxy sanitizes an attachment's stored HTML before painting it in the editor, and
// iframe isn't on its allow-list — so a YouTube embed showed the writer an empty box
// while the identical markup played for every reader on the public page. Lexxy takes
// extra allowed elements from a configured extension, so declare the one tag its
// allow-list is missing rather than reaching into the gem.
//
// This is display-only, and strictly narrower than what already ships: the server's
// Action Text allow-list (config/initializers/action_text_tags.rb) permits iframe for
// the same bodies, so these frames already render for the whole internet. Lexxy's hook
// is tag-and-attribute granular — it can't filter on src — so this can't be pinned to
// youtube.com alone. That costs nothing here: the frames come from Embed, which only
// ever builds a YouTube src.
class EmbedFrames extends Extension {
  get allowedElements() {
    return [ { tag: "iframe", attributes: [ "width", "height", "frameborder", "allow", "allowfullscreen" ] } ]
  }
}

// Lexxy defers defining its elements until the current call stack drains, so
// configuring here — right after the writing entry imports it — lands in time.
configure({ global: { extensions: [ EmbedFrames ] } })
