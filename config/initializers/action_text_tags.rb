# Ghost bodies carry semantic markup Action Text strips by default — figures with
# captions, embed iframes, toggle <details>. Widen the allow-list so migrated
# content renders as authored. This is trusted, single-author content.
#
# Provisional for the importer stage; Phase 2 (reader parity) owns the final
# kg-card allow-list + CSS.
Rails.application.config.after_initialize do
  base = ActionText::ContentHelper.sanitizer.class.allowed_tags
  ActionText::ContentHelper.allowed_tags =
    base.to_a + %w[figure figcaption iframe details summary]

  base_attrs = ActionText::ContentHelper.sanitizer.class.allowed_attributes
  ActionText::ContentHelper.allowed_attributes =
    base_attrs.to_a + %w[class srcset sizes loading allowfullscreen frameborder allow scrolling]
end
