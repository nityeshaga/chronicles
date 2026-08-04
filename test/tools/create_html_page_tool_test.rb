require "test_helper"

class CreateHtmlPageToolTest < ActiveSupport::TestCase
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
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, CreateHtmlPageTool.new.call(title: "X", html: DOCUMENT)
  end

  test "always creates a draft, auto-slugging from the title, with the canonical injected once" do
    result = CreateHtmlPageTool.new.call(title: "A Landing Page", html: DOCUMENT)

    page = HtmlPage.find(result[:id])
    assert page.draft?
    assert_equal "draft", result[:status]
    assert_equal "a-landing-page", result[:slug]
    assert_includes result[:edit_url], "/writing/html_pages/a-landing-page/edit"
    assert_includes result[:message], "publish_post"
    assert_nil result[:warnings]

    canonical = %(<link rel="canonical" href="https://#{Setting.current.production_host}/a-landing-page/">)
    assert_includes page.raw_html, canonical
    assert_equal 1, page.raw_html.scan(/rel="canonical"/).size
    assert_equal DOCUMENT.sub("</head>", "#{canonical}\n</head>"), page.raw_html
  end

  test "honors an explicit slug and canonicalizes to it" do
    result = CreateHtmlPageTool.new.call(title: "A Landing Page", html: DOCUMENT, slug: "hands-on-deck-2")

    assert_equal "hands-on-deck-2", result[:slug]
    assert_includes HtmlPage.find(result[:id]).raw_html, "href=\"https://#{Setting.current.production_host}/hands-on-deck-2/\""
  end

  test "a fragment is refused by the model validation" do
    result = CreateHtmlPageTool.new.call(title: "Fragment", html: "<h1>Just a headline</h1>")

    assert_includes result[:error], "complete HTML document"
    assert_nil HtmlPage.find_by(slug: "fragment")
  end

  test "a document with no title in the head is a hard fail" do
    titleless = DOCUMENT.sub("<title>Hands on Deck</title>", "")
    result = CreateHtmlPageTool.new.call(title: "Titleless", html: titleless)

    assert_includes result[:error], "<title>"
    assert_nil HtmlPage.find_by(slug: "titleless")
  end

  test "a missing meta description warns but still creates the draft" do
    naked = DOCUMENT.sub(%r{<meta name="description".*>\n}, "")
    result = CreateHtmlPageTool.new.call(title: "No Description", html: naked)

    assert_nil result[:error]
    assert HtmlPage.find(result[:id])
    assert_equal 1, result[:warnings].size
    assert_includes result[:warnings].first, "description"
  end

  test "a self-referential canonical is preserved untouched" do
    canonical = %(<link rel="canonical" href="https://#{Setting.current.production_host}/self-canonical/">)
    html = DOCUMENT.sub("</head>", "#{canonical}\n</head>")

    result = CreateHtmlPageTool.new.call(title: "Self Canonical", html: html, slug: "self-canonical")

    assert_equal html, HtmlPage.find(result[:id]).raw_html
    assert_nil result[:warnings]
  end

  test "a foreign canonical is warned about, never overwritten" do
    html = DOCUMENT.sub("</head>", %(<link rel="canonical" href="https://everyinc.github.io/hands-on-deck/">\n</head>))

    result = CreateHtmlPageTool.new.call(title: "Foreign Canonical", html: html)

    page = HtmlPage.find(result[:id])
    assert_equal html, page.raw_html
    assert_equal 1, page.raw_html.scan(/rel="canonical"/).size
    assert result[:warnings].any? { |warning| warning.include?("everyinc.github.io") }
  end

  test "relative asset references warn, absolute ones and anchors do not" do
    html = DOCUMENT.sub("<body>", %(<body><img src="img/foo.png"><a href="#top">top</a><img src="https://cdn.example.com/a.png">))

    result = CreateHtmlPageTool.new.call(title: "Relative Assets", html: html)

    warning = result[:warnings].find { |w| w.include?("Relative references") }
    assert_includes warning, "img/foo.png"
    assert_not_includes warning, "cdn.example.com"
    assert_not_includes warning, "#top"
  end

  test "site-absolute references get the milder note" do
    html = DOCUMENT.sub("<body>", %(<body><img src="/content/images/hero.png">))

    result = CreateHtmlPageTool.new.call(title: "Site Absolute", html: html)

    assert result[:warnings].none? { |w| w.include?("Relative references") }
    assert result[:warnings].any? { |w| w.include?("Site-absolute") && w.include?("/content/images/hero.png") }
  end
end
