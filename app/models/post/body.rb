# The prose, and the two things every way of writing it owes the page. Both live on the
# model because the editor is not the only writer: the MCP tools and the console save bodies
# too, and a rule that lived in the autosave path would hold for one of the three.
#
# Trimmed: the editor's empty value is <p><br></p>, and bodies collect them at the edges —
# after a table, after a paste, under the last line — where they publish as nothing but
# vertical space; the Ghost import left an empty first paragraph on many posts. Only the
# edges. A blank paragraph between two others is a blank line the writer put there.
#
# Canonical: a content attachment carries its markup in a `content` attribute, and the
# renderer sanitizes that attribute on every page view (ActionText::Content#render_attachments).
# The editor reads the rendered form back and writes it as the attribute again, so a body
# stored with unsanitized markup — a tweet's <script>, Ghost's data-* hooks, the view
# annotations development adds — changed shape on its next save with nothing typed. Running
# the renderer's own pass on the way in makes the first save store what every later render
# and save will produce. Stripped, because the annotations leave their newlines behind when
# the sanitizer takes the comments, and a card means nothing by the whitespace around it.
module Post::Body
  extend ActiveSupport::Concern

  included do
    has_rich_text :body
    # A body never loaded can't have changed, and most saves — publish, unpublish, the
    # newsletter stamp — never load it. Asked of the cache, not the association: merely
    # instantiating the association is what makes autosave load it at the end of the save.
    before_save :shape_body, if: -> { association_cached?(:rich_text_body) && rich_text_body&.body_changed? }
  end

  # The body without the blank paragraphs at either end. A blank paragraph is one a reader
  # can't see: <p><br></p>, <p></p>, or whitespace and &nbsp; alone.
  def self.trim(html)
    ActionText::Fragment.wrap(html.to_s).update do |source|
      source.children.each { |node| break unless remove_if_blank(node) }
      source.children.reverse_each { |node| break unless remove_if_blank(node) }
    end.to_html
  end

  # The body with every content attachment's markup in the shape the renderer will give it.
  def self.canonicalize(html)
    content = ActionText::Content.new(html.to_s)
    content.fragment.replace("#{ActionText::Attachment.tag_name}[content]") do |node|
      node["content"] = content.sanitize_content_attachment(node["content"]).strip
      node
    end.to_html
  end

  def self.remove_if_blank(node)
    return false unless node.text? || node.name == "p"
    return false unless node.element_children.all? { |child| child.name == "br" } && node.text.blank?

    node.remove
    true
  end
  private_class_method :remove_if_blank

  # The HtmlCards this body attaches. They are content the post renders but does not own,
  # so anything caching a rendered post has to key on them too.
  def html_cards = body&.body&.attachables.to_a.grep(HtmlCard)

  private
    def shape_body
      body.body = Post::Body.trim(Post::Body.canonicalize(body.body&.to_html))
    end
end
