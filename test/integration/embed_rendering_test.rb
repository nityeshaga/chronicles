require "test_helper"

# End-to-end proof that a pasted-URL embed survives the round trip: the editor
# inserts it as an Action Text content attachment (content-type text/html, per
# EmbedsController + the embed Stimulus controller), Action Text stores it, and the
# PUBLIC renderer paints the provider markup — the same path imported embeds use.
class EmbedRenderingTest < ActionDispatch::IntegrationTest
  # The exact body Lexxy submits for an inserted html content attachment: an
  # <action-text-attachment> carrying the provider HTML in its `content` attribute.
  def editor_embed(url)
    inner = Embed.new(url).to_html
    %(<action-text-attachment content-type="text/html" ) +
      %(content="#{ERB::Util.html_escape(inner)}"></action-text-attachment>)
  end

  test "a tweet embed renders on the public post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: editor_embed("https://twitter.com/nityeshaga/status/999") } }
    post writing_post_publishing_url(draft)

    get post_url(draft.reload)
    follow_redirect!
    assert_response :success
    assert_select "blockquote.twitter-tweet"
  end

  test "a YouTube embed renders an iframe on the public post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: editor_embed("https://youtu.be/abc123XYZ_9") } }
    post writing_post_publishing_url(draft)

    get post_url(draft.reload)
    follow_redirect!
    assert_response :success
    assert_select "iframe[src*=?]", "youtube.com/embed/abc123XYZ_9"
  end
end
