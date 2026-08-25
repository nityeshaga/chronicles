require "test_helper"

# Heading ids are derived at render, never stored: the public page and the writer's preview
# carry them, the editor's form value does not. An imported post's ids reproduce what Ghost
# minted so the links people already hold still land; a post written here gets readable ones.
class HeadingAnchorsTest < ActionDispatch::IntegrationTest
  # Real headings from imported posts, with the ids Ghost stored on them, by the Ghost that
  # minted them. The Ghost 3 post's 36th heading is an h1, which the body leaves to the title.
  GHOST3_HEADINGS = {
    "What you will learn" => "what-you-will-learn",
    %(Q: "Alright, what am I building?" 😃) => "q-alright-what-am-i-building-",
    "Okay so here's the idea:" => "okay-so-here-s-the-idea-",
    "MS3: Features #1 and #2 - Count the total no. of messages and total no. of words" =>
      "ms3-features-1-and-2-count-the-total-no-of-messages-and-total-no-of-words",
    "What are modules?" => "what-are-modules",
    "3 Systems to help teach yourself &lt;some X&gt;" => "3-systems-to-help-teach-yourself-some-x"
  }.freeze

  GHOST4_HEADINGS = {
    "Example Workflow:" => "example-workflow",
    "TL;DR" => "tldr",
    "The IDE Problem (Cursor, etc.)" => "the-ide-problem-cursor-etc",
    "What If “Jobs” Disappear—And Curiosity Takes Their Place?" =>
      "what-if-%E2%80%9Cjobs%E2%80%9D-disappear%E2%80%94and-curiosity-takes-their-place"
  }.freeze

  # The importer is the only writer of raw_source, so carrying any is what makes a post
  # imported, and the mobiledoc's ghostVersion is what says which Ghost minted its ids.
  def publish(body, ghost_version: nil)
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    draft.update!(raw_source: { ghostVersion: ghost_version }.to_json) if ghost_version
    patch writing_post_url(draft), params: { post: { body: body } }
    post writing_post_publishing_url(draft)
    # Spend the popover flash on the edit page it was meant for, not on the page under test.
    follow_redirect!
    draft.reload
  end

  test "h2 to h4 carry ids on the public page and a repeated heading counts up" do
    published = publish("<h2>Foo</h2><p>a</p><h3>Foo</h3><p>b</p><h4>Bar</h4><h2>Foo</h2>")

    get post_url(published)
    follow_redirect!
    assert_select "h2#foo", "Foo"
    assert_select "h3#foo-2", "Foo"
    assert_select "h4#bar", "Bar"
    assert_select "h2#foo-3", "Foo"
  end

  test "an h1 in the body gets no id" do
    published = publish("<h1>Title again</h1><h2>Section</h2>")

    get post_url(published)
    follow_redirect!
    assert_select ".gh-content h1[id]", false
    assert_select "h2#section"
  end

  test "a post written here gets an anchor a reader would type" do
    published = publish("<h2>How to debug your code:</h2><h3>Okay so here's the idea:</h3><h3>TL;DR</h3>")

    get post_url(published)
    follow_redirect!
    assert_select "h2#how-to-debug-your-code"
    assert_select "h3#okay-so-heres-the-idea"
    assert_select "h3#tl-dr"
  end

  test "a heading the slug keeps nothing of goes without an id" do
    published = publish("<h2>हिन्दी</h2><h2>हिन्दी</h2><h2>🎉</h2><h2>Foo</h2>")

    get post_url(published)
    follow_redirect!
    assert_select ".gh-content h2[id]", 1
    assert_select "h2#foo"
  end

  test "a Ghost 3 post's ids reproduce what Ghost stored" do
    published = publish(GHOST3_HEADINGS.keys.map { |text| "<h3>#{text}</h3>" }.join, ghost_version: "3.0")

    get post_url(published)
    follow_redirect!
    GHOST3_HEADINGS.each_value { |id| assert_select "h3[id=?]", id }
  end

  test "a Ghost 4 post's ids reproduce what Ghost stored" do
    published = publish(GHOST4_HEADINGS.keys.map { |text| "<h3>#{text}</h3>" }.join, ghost_version: "4.0")

    get post_url(published)
    follow_redirect!
    GHOST4_HEADINGS.each_value { |id| assert_select "h3[id=?]", id }
  end

  test "an imported post's repeated heading reproduces Ghost's counter" do
    published = publish("<h3>This is a good opportunity to go deep and:</h3><h3>This is a good opportunity to go deep and:</h3>", ghost_version: "3.0")

    get post_url(published)
    follow_redirect!
    assert_select "h3#this-is-a-good-opportunity-to-go-deep-and-"
    assert_select "h3#this-is-a-good-opportunity-to-go-deep-and--1"
  end

  # The same headings, three promises: the new post's readable anchor, and the old links
  # each Ghost minted.
  test "whether a post was imported, and by which Ghost, picks the slugger" do
    published = publish("<h2>How to debug your code:</h2><h2>What If “Jobs” Disappear—And Curiosity Takes Their Place?</h2>")

    get post_url(published)
    follow_redirect!
    assert_select "h2#how-to-debug-your-code"
    assert_select "h2#what-if-jobs-disappear-and-curiosity-takes-their-place"

    published.update!(raw_source: { ghostVersion: "3.0" }.to_json)
    get post_url(published, trailing_slash: true)
    assert_select "h2#how-to-debug-your-code-"
    assert_select "h2#what-if-jobs-disappear-and-curiosity-takes-their-place"

    published.update!(raw_source: { ghostVersion: "4.0" }.to_json)
    get post_url(published, trailing_slash: true)
    assert_select "h2#how-to-debug-your-code"
    assert_select "h2[id=?]", "what-if-%E2%80%9Cjobs%E2%80%9D-disappear%E2%80%94and-curiosity-takes-their-place"
  end

  test "the writer's preview carries the same ids" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: "<h2>Preview me</h2>" } }

    get writing_post_url(draft.reload)
    assert_select "h2#preview-me"
  end

  # The editor gets the body as stored. An id in the form value would be saved back, and
  # then it would be a stored id again — the thing this replaces.
  test "the editor's form value carries no heading ids" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: "<h2>Foo</h2>" } }

    get edit_writing_post_url(draft.reload)
    value = css_select("lexxy-editor[name='post[body]']").first["value"]
    assert_includes value, "<h2>Foo</h2>"
    assert_not_includes value, "id="
  end

  test "the stored body carries no heading ids" do
    published = publish("<h2>Foo</h2>")
    assert_equal "<h2>Foo</h2>", published.body.body.to_html
  end

  test "the page still answers a conditional GET with 304" do
    published = publish("<h2>Foo</h2>")
    delete session_url

    get post_url(published, trailing_slash: true)
    assert_response :success
    etag = response.headers["ETag"]

    get post_url(published, trailing_slash: true), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end
end
