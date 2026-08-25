require "test_helper"

# Code colour is derived at render, never stored: the public page and the writer's preview
# carry Rouge's spans and the language label, the editor's form value carries the body as
# the editor exported it.
class CodeHighlightingRenderingTest < ActionDispatch::IntegrationTest
  BODY = %(<p>Intro</p><pre data-language="ruby" data-highlight-language="ruby">def publish<br>  touch :published_at<br>end</pre>)

  def publish(body)
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: body } }
    post writing_post_publishing_url(draft)
    follow_redirect!
    draft.reload
  end

  test "a published code block is coloured and labelled on the public page" do
    published = publish(BODY)

    get post_url(published, trailing_slash: true)
    assert_select "pre.highlight[data-language=ruby]" do
      assert_select "code span.k", text: "def"
      assert_select "code span.nf", text: "publish"
      assert_select ".highlight__language", text: "Ruby"
      assert_select "button.highlight__copy[data-action='clipboard#copy']"
    end
    assert_select "pre br", false
  end

  test "a pasted fence keeps its language on the public page" do
    published = publish(%(<pre><code class="language-python">print("hi")</code></pre>))

    get post_url(published, trailing_slash: true)
    assert_select "pre.highlight[data-language=python] .highlight__language", text: "Python"
  end

  test "the writer's preview shows the same colouring" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: BODY } }

    get writing_post_url(draft.reload)
    assert_select "pre.highlight[data-language=ruby] code span.k", text: "def"
  end

  test "the stored body and the editor's form value carry none of it" do
    published = publish(BODY)

    assert_equal BODY, published.body.body.to_html
    get edit_writing_post_url(published)
    value = css_select("lexxy-editor[name='post[body]']").first["value"]
    assert_not_includes value, "highlight__"
    assert_not_includes value, %(class="highlight")
  end

  test "the page still answers a conditional GET with 304" do
    published = publish(BODY)
    delete session_url

    get post_url(published, trailing_slash: true)
    assert_response :success
    etag = response.headers["ETag"]

    get post_url(published, trailing_slash: true), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end
end
