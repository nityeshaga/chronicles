# A fragment of hand-authored markup dropped between paragraphs and served exactly as
# written — a bespoke table, a CSS grid, a chart that draws itself. Ghost calls it an HTML
# card. Here it is a record the body attaches by sgid, and the bytes never travel in the
# body at all.
#
# That last part was forced, and it turned out to be the better design anyway. Action Text
# will not carry raw markup through a render: `ActionText::Content#render_attachments`
# re-sanitizes a content attachment's `content` attribute on the way out (actiontext's
# content.rb, `sanitize_content_attachment(node.remove_attribute("content").to_s)`), and
# then sanitizes the whole rendered document again. Nothing rendered inside Action Text
# survives, and the attribute the bytes would ride in is scrubbed on every page view. So
# the body carries a reference and the record carries the bytes — which also keeps a
# 267KB chart out of every autosave, every editor payload and every stored revision.
#
# Two forms, and the difference is the whole class:
#
#   content      — what the author wrote. Reaches a browser at two seams and nowhere else:
#                  HtmlCard.expand, on the public post, and Writing::HtmlCardsController#show,
#                  which serves one card bare for the writer's canvas to frame. Both read
#                  the record; the bytes still never ride in a body or an attachment.
#   static_html  — the same markup with script and style pruned *with their contents*.
#                  This is what the attachment partial renders, so email, feeds, search
#                  descriptions and reading time get the readable skeleton for free rather
#                  than each having to remember to ask. Pruning matters: Rails' sanitizer
#                  strips a <script> tag but keeps the JavaScript inside it as text, which
#                  would mail a chart's source code to a subscriber as prose.
#
# A card is trusted content — the same trust the writing dashboard already extends to
# HtmlPage, which serves an author's scripts verbatim on this origin. The boundary is who
# can write, not what renders.
class HtmlCard < ApplicationRecord
  include ActionText::Attachable

  validates :content, presence: true

  STATIC_SELECTOR = ".kg-html-card--static"

  # The one place a card's bytes reach a browser. Swaps each card attachment in a rendered
  # body for its markup, wrapped in the Ghost card class so the theme gives it the same
  # vertical rhythm as an image or an embed.
  #
  # The static skeletons go first, and separately, because an HTML parser will not leave a
  # <div> inside the <p> the editor puts an inline attachment in: by the time this reads the
  # body, a skeleton may have been hoisted clear of the attachment it belongs to, where
  # replacing the attachment can no longer reach it. Clearing them by class finds them
  # wherever the parser moved them.
  def self.expand(html)
    html = html.to_s
    return html.html_safe unless html.include?(ActionText::Attachment.tag_name)

    fragment = ActionText::Fragment.wrap(html).update { |body| body.css(STATIC_SELECTOR).each(&:remove) }

    fragment.replace(ActionText::Attachment.tag_name) do |node|
      card = ActionText::Attachable.from_node(node)
      card.is_a?(HtmlCard) ? %(<div class="kg-card kg-html-card">#{card.content}</div>) : node
    end.to_html.html_safe
  end

  # Whether a body loses something a reader would notice when its cards go static — the
  # cue for a mail to say so, rather than leave a subscriber staring at a chart's caption
  # above nothing. Asks the body for its attachables rather than re-parsing a render: the
  # records are already loaded by the time anyone wants to know.
  def self.interactive_in?(rich_text)
    rich_text&.body&.attachables.to_a.grep(HtmlCard).any? { |card| card.content.include?("<script") }
  end

  # Lexxy asks the attachment for this on every editor load — `node["content-type"] ||=
  # attachment.content_type` in lexxy's rich_text_area_tag — and ActionText::Attachment
  # forwards what it doesn't know to the attachable. Without it, opening any post that
  # carries a card raises NoMethodError before the page renders.
  def content_type = "text/html"

  def static_html
    self.class.pruner.sanitize(content,
      tags: ActionText::ContentHelper.allowed_tags,
      attributes: ActionText::ContentHelper.allowed_attributes).html_safe
  end

  # Pruning, not stripping: a disallowed element leaves with its contents.
  def self.pruner = @pruner ||= Rails::HTML5::SafeListSanitizer.new(prune: true)
end
