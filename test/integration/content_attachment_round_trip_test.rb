require "test_helper"

# The body is sacred: what the editor reads for an opaque card it must write back unchanged.
# Action Text's own content-attachment partial broke that — every render wrapped the
# content in one more <figure class="attachment attachment--content">, and Lexxy saved the
# wrapped form (post 76 reached ten). These tests hold the two halves of the fix: the render
# is a fixed point, and the stored attribute is already in the renderer's shape.
class ContentAttachmentRoundTripTest < ActionDispatch::IntegrationTest
  FIGURE = %(<figure class="kg-card kg-embed-card"><iframe src="https://www.youtube.com/embed/abc123XYZ_9" width="560" height="315" frameborder="0" allowfullscreen=""></iframe></figure>)

  setup do
    sign_in_as users(:nityesh)
    @draft = posts(:draft)
  end

  def opaque(html)
    %(<p><action-text-attachment content-type="text/html" content="#{ERB::Util.html_escape(html)}"></action-text-attachment></p>)
  end

  # The value Lexxy hands the editor carries each attachment's rendered content, and what
  # the editor saves is that content as the node's `content` attribute — the stored body
  # after a save with nothing typed.
  def editor_value
    get edit_writing_post_url(@draft)
    Nokogiri::HTML5.fragment(response.body).at_css("lexxy-editor")["value"]
  end

  def save_as_the_editor_would(value)
    body = ActionText::Fragment.wrap(value).replace("action-text-attachment[content]") do |node|
      node["content"] = JSON.parse(node["content"])
      node
    end.to_html
    patch writing_post_url(@draft), params: { post: { body: } }
  end

  def stored_body = @draft.reload.body.body.to_html
  def stored_content = Nokogiri::HTML5.fragment(stored_body).at_css("action-text-attachment")["content"]

  test "an opaque card renders once on the public page, with no wrapper" do
    patch writing_post_url(@draft), params: { post: { body: opaque(FIGURE) } }
    post writing_post_publishing_url(@draft)

    get post_url(@draft.reload)
    follow_redirect!
    assert_equal 1, response.body.scan("<figure").size
    assert_select "figure.kg-embed-card iframe", 1
    assert_select ".attachment--content", false
  end

  test "the editor writes back what it read, save after save" do
    patch writing_post_url(@draft), params: { post: { body: opaque(FIGURE) } }
    first = stored_body
    assert_equal FIGURE, stored_content

    value = editor_value
    save_as_the_editor_would(value)
    assert_equal first, stored_body

    assert_equal value, editor_value
    save_as_the_editor_would(value)
    assert_equal first, stored_body
  end

  test "content is stored in the renderer's shape, so the first save is the last change" do
    raw = %(\n<!-- BEGIN a view annotation -->\n<figure class="kg-card kg-embed-card" data-kg-hook="x"><blockquote class="twitter-tweet"><a href="https://twitter.com/x/status/1">tweet</a></blockquote><script async src="https://platform.twitter.com/widgets.js"></script></figure>\n<!-- END -->\n)
    patch writing_post_url(@draft), params: { post: { body: opaque(raw) } }

    stored = stored_body
    refute_includes stored_content, "script"
    refute_includes stored_content, "data-kg-hook"
    refute_includes stored_content, "<!--"
    assert_equal stored_content, stored_content.strip
    assert_includes stored_content, %(<blockquote class="twitter-tweet">)

    save_as_the_editor_would(editor_value)
    assert_equal stored, stored_body
  end
end
