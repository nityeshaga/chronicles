require "test_helper"

class UpdateHtmlPageToolTest < ActiveSupport::TestCase
  DOCUMENT = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <title>Hands on Deck</title>
    <meta name="description" content="A landing page.">
    </head>
    <body><h1>Hands on Deck</h1></body>
    </html>
  HTML

  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
    @page = HtmlPage.find(CreateHtmlPageTool.new.call(title: "Hands on Deck", html: DOCUMENT, slug: "landing")[:id])
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, UpdateHtmlPageTool.new.call(id_or_slug: "landing", title: "X")
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::POST_NOT_FOUND, UpdateHtmlPageTool.new.call(id_or_slug: "nope", title: "X")
  end

  test "refuses a regular post and names the tool that handles it" do
    result = UpdateHtmlPageTool.new.call(id_or_slug: "a-draft-post", html: DOCUMENT)

    assert_equal ToolErrors::NOT_AN_HTML_PAGE, result
    assert_includes result[:error], "update_post"
  end

  test "updates the title without touching the document" do
    before = @page.raw_html
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", title: "Renamed")

    assert_equal [ "title" ], result[:changed]
    assert_equal "Renamed", @page.reload.title
    assert_equal before, @page.raw_html
  end

  test "a full replacement re-runs the gate" do
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", html: DOCUMENT.sub("<body>", %(<body><img src="img/foo.png">)))

    assert_includes result[:changed], "html"
    assert result[:warnings].any? { |warning| warning.include?("img/foo.png") }
    assert_equal 1, @page.reload.raw_html.scan(/rel="canonical"/).size
  end

  test "a full replacement that is a fragment is refused and changes nothing" do
    before = @page.raw_html
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", html: "<h1>nope</h1>")

    assert_includes result[:error], "complete HTML document"
    assert_equal before, @page.reload.raw_html
  end

  test "a full replacement with no title is refused and changes nothing" do
    before = @page.raw_html
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", html: DOCUMENT.sub("<title>Hands on Deck</title>", ""))

    assert_includes result[:error], "<title>"
    assert_equal before, @page.reload.raw_html
  end

  test "html_patches apply surgically and are counted" do
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", html_patches: [ { "old" => "<h1>Hands on Deck</h1>", "new" => "<h1>All Hands</h1>" } ])

    assert_nil result[:error]
    assert_equal 1, result[:html_patches_applied]
    assert_includes @page.reload.raw_html, "<h1>All Hands</h1>"
    assert_equal 1, @page.raw_html.scan(/rel="canonical"/).size
  end

  test "html_patches with zero matches errors, names the index, and changes nothing" do
    before = @page.raw_html
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", html_patches: [ { "old" => "nonexistent", "new" => "x" } ])

    assert_includes result[:error], "Patch 0"
    assert_includes result[:error], "get_post"
    assert_equal before, @page.reload.raw_html
  end

  test "html_patches with multiple matches asks for more context" do
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", html_patches: [ { "old" => "Hands on Deck", "new" => "All Hands" } ])

    assert_includes result[:error], "more than once"
    assert_includes @page.reload.raw_html, "Hands on Deck"
  end

  test "html and html_patches are mutually exclusive" do
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", html: DOCUMENT, html_patches: [ { "old" => "a", "new" => "b" } ])
    assert_includes result[:error], "mutually exclusive"
  end

  test "renaming a published page rewrites its self-referential canonical and warns about the 404" do
    @page.publish
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", slug: "hands-on-deck-live")

    assert_equal "hands-on-deck-live", result[:slug]
    assert_includes @page.reload.raw_html, %(href="https://#{Setting.current.production_host}/hands-on-deck-live/")
    assert_not_includes @page.raw_html, "/landing/"
    assert_equal 1, @page.raw_html.scan(/rel="canonical"/).size
    assert result[:warnings].any? { |warning| warning.include?("404") }
    assert result[:warnings].any? { |warning| warning.include?("rewritten") }
  end

  test "renaming leaves a foreign canonical alone and says so" do
    foreign = DOCUMENT.sub("</head>", %(<link rel="canonical" href="https://everyinc.github.io/hands-on-deck/">\n</head>))
    UpdateHtmlPageTool.new.call(id_or_slug: "landing", html: foreign)

    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", slug: "renamed-landing")

    assert_includes @page.reload.raw_html, "https://everyinc.github.io/hands-on-deck/"
    assert result[:warnings].any? { |warning| warning.include?("everyinc.github.io") }
  end

  test "a draft rename carries no 404 warning" do
    result = UpdateHtmlPageTool.new.call(id_or_slug: "landing", slug: "renamed-draft-page")

    assert_equal "renamed-draft-page", result[:slug]
    assert_nil result[:warnings]&.find { |warning| warning.include?("404") }
  end

  test "repeated edits never inject a second canonical" do
    UpdateHtmlPageTool.new.call(id_or_slug: "landing", html_patches: [ { "old" => "Hands on Deck</h1>", "new" => "All Hands</h1>" } ])
    UpdateHtmlPageTool.new.call(id_or_slug: "landing", html: @page.reload.raw_html.sub("All Hands", "Many Hands"))
    UpdateHtmlPageTool.new.call(id_or_slug: "landing", html_patches: [ { "old" => "Many Hands</h1>", "new" => "Two Hands</h1>" } ])

    assert_equal 1, @page.reload.raw_html.scan(/rel="canonical"/).size
    assert_includes @page.raw_html, "Two Hands</h1>"
  end
end
