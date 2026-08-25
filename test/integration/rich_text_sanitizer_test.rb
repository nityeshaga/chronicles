require "test_helper"

# The rendered allow-list is the union of two on_load(:action_text_content) hooks, Lexxy's
# and ours, and has to come out the same whichever fires first. This suite loads lazily by
# default and eagerly under CI=1, so the same test stands guard in both orders.
class RichTextSanitizerTest < ActionDispatch::IntegrationTest
  BODY = %(<figure class="kg-card kg-embed-card"><iframe src="https://www.youtube.com/embed/x" allowfullscreen></iframe><figcaption>cap</figcaption></figure>) +
         %(<details><summary>more</summary>hidden</details>) +
         %(<pre data-language="ruby"><code>1</code></pre>) +
         %(<p><mark style="background-color:rgb(255,230,0)">hi</mark></p>) +
         %(<ol start="5"><li value="5">five</li></ol>) +
         %(<video src="x.mp4" controls></video>) +
         %(<p><s>gone</s> <u>kept</u></p>)

  test "everything the editor can write survives to the public post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: BODY } }
    post writing_post_publishing_url(draft)

    get post_url(draft.reload)
    follow_redirect!
    assert_response :success

    assert_select "figure.kg-embed-card iframe[allowfullscreen][src*=?]", "youtube.com/embed/x"
    assert_select "figure figcaption", "cap"
    assert_select "details summary", "more"
    assert_select "pre[data-language=ruby] code", "1"
    assert_select "mark[style*=?]", "background-color", text: "hi"
    assert_select "ol[start=5] li[value=5]", "five"
    assert_select "video[controls][src=?]", "x.mp4"
    assert_select "s", "gone"
    assert_select "u", "kept"
  end

  # The lists are filled by the on_load hooks, so they are nil until ActionText::Content
  # has loaded; under lazy loading nothing else in this test asks for it.
  test "the allow-list is the union of Lexxy's additions and ours" do
    ActionText::Content.new("")
    tags = ActionText::ContentHelper.allowed_tags.to_a
    attributes = ActionText::ContentHelper.allowed_attributes.to_a

    assert_empty %w[video audio source embed iframe details summary s u table action-text-attachment] - tags
    assert_empty %w[controls poster data-language style value start sgid class srcset allowfullscreen colspan href width] - attributes

    assert_not_includes attributes, "id"
    assert_not_includes attributes, "content"
  end
end
