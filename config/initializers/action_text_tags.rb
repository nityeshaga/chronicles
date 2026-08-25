# Ghost bodies carry semantic markup Action Text strips by default — embed iframes,
# toggle <details>, tables — and the editor writes <s> and <u>, which the default list
# spells del/ins. Widen the allow-list so content renders as authored. This is trusted,
# single-author content.
#
# Tables are prose, not decoration: they belong in the body proper rather than inside an
# HtmlCard, because a subscriber's mail client renders a real table natively and a card
# goes static there.
#
# Lexxy widens the same two lists from its own on_load(:action_text_content) hook, and it
# extends whatever list is current rather than starting from Rails' base. This file does the
# same, from the same hook, so the result is one union whichever hook fires first.
#
# `style` arrives through Lexxy's list because the highlight colours live in it. The same
# attribute carries the widths and cell colours Lexxy writes on exported tables, so an
# author-resized column or a coloured cell now reaches the public table too; that is the
# accepted price on a single-author site, the public table CSS decides the look, and
# Loofah's CSS scrubber keeps every style to safe properties. `id` is nobody's, and stays out.
#
# Rails' default attribute list carries every ActionText::Attachment::ATTRIBUTES, and the
# public page has no use for them: `content` would serve an embed's whole escaped HTML a
# second time beside the rendered one, and the rest is metadata already rendered inside the
# node. Only `sgid` stays, because HtmlCard.expand finds a card by the sgid on its
# attachment node and a stripped node is an unfindable card.
ActiveSupport.on_load(:action_text_content) do
  current = Object.new.extend(ActionText::ContentHelper)
  attachment_only = ActionText::Attachment::ATTRIBUTES - current.sanitizer.class.allowed_attributes.to_a

  ActionText::ContentHelper.allowed_tags =
    current.sanitizer_allowed_tags + %w[iframe details summary s u
                                      table thead tbody tfoot tr td th caption colgroup col]

  ActionText::ContentHelper.allowed_attributes =
    current.sanitizer_allowed_attributes - attachment_only +
      %w[sgid class srcset sizes loading allowfullscreen frameborder allow scrolling colspan rowspan]
end
