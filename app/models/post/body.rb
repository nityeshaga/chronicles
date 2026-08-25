# The prose, and the two things every way of writing it owes the page. The editor's empty
# value is <p><br></p>, and bodies collect them at the edges — after a table, after a paste,
# under the last line — where they publish as nothing but vertical space; the Ghost import
# left an empty first paragraph on many posts. Trimmed on the model because the editor is
# not the only writer: the MCP tools and the console save bodies too, and a rule that lived
# in the autosave path would hold for one of the three.
#
# Only the edges. A blank paragraph between two others is a blank line the writer put there.
module Post::Body
  extend ActiveSupport::Concern

  included do
    has_rich_text :body
    # A body never loaded can't have changed, and most saves — publish, unpublish, the
    # newsletter stamp — never load it. Asked of the cache, not the association: merely
    # instantiating the association is what makes autosave load it at the end of the save.
    before_save :trim_body, if: -> { association_cached?(:rich_text_body) && rich_text_body&.body_changed? }
  end

  # The body without the blank paragraphs at either end. A blank paragraph is one a reader
  # can't see: <p><br></p>, <p></p>, or whitespace and &nbsp; alone.
  def self.trim(html)
    ActionText::Fragment.wrap(html.to_s).update do |source|
      source.children.each { |node| break unless remove_if_blank(node) }
      source.children.reverse_each { |node| break unless remove_if_blank(node) }
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
    def trim_body
      body.body = Post::Body.trim(body.body&.to_html)
    end
end
