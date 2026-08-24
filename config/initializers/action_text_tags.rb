# Ghost bodies carry semantic markup Action Text strips by default — figures with
# captions, embed iframes, toggle <details>, and tables. Widen the allow-list so migrated
# content renders as authored. This is trusted, single-author content.
#
# Tables are prose, not decoration: they belong in the body proper rather than inside an
# HtmlCard, because a subscriber's mail client renders a real table natively and a card
# goes static there. `style` and `id` stay out — the Lexxy editor decorates table cells
# with both on export, and nothing else wants them.
#
# The attachment element and its sgid have to be re-added by hand. Action Text only
# appends them in the branch it takes when nobody has set an allow-list of their own
# (ActionText::ContentHelper#sanitizer_allowed_tags), so the moment this file assigns one
# that branch is gone. HtmlCard.expand finds a card by the sgid on its attachment node, so
# stripping the node is what would make every card unfindable in a rendered body. The rest
# of ActionText::Attachment::ATTRIBUTES stays out, `content` most of all: no attachment on
# this site keeps anything there worth serving twice.
Rails.application.config.after_initialize do
  base = ActionText::ContentHelper.sanitizer.class.allowed_tags
  ActionText::ContentHelper.allowed_tags =
    base.to_a + %w[figure figcaption iframe details summary
                   table thead tbody tfoot tr td th caption colgroup col
                   action-text-attachment]

  base_attrs = ActionText::ContentHelper.sanitizer.class.allowed_attributes
  ActionText::ContentHelper.allowed_attributes =
    base_attrs.to_a + %w[class srcset sizes loading allowfullscreen frameborder allow scrolling
                         colspan rowspan sgid]
end
