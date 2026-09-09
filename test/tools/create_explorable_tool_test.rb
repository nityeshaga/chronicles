require "test_helper"

class CreateExplorableToolTest < ActiveSupport::TestCase
  INDEX = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <title>Hotwire, explored</title>
    <meta name="description" content="Turbo and Stimulus, deck by deck.">
    <link rel="stylesheet" href="shared/style.css">
    </head>
    <body><a href="decks/10-drive.html">Start</a></body>
    </html>
  HTML

  DECK = %(<!DOCTYPE html><html><head><title>Drive</title><link rel="stylesheet" href="../shared/style.css"></head><body><a href="../index.html">Home</a></body></html>)

  FILES = [
    { "path" => "index.html", "content" => INDEX },
    { "path" => "shared/style.css", "content" => "body{}" },
    { "path" => "decks/10-drive.html", "content" => DECK }
  ].freeze

  setup do
    Thread.current[:mcp_current_user] = users(:nityesh)
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, CreateExplorableTool.new.call(title: "X", files: FILES)
  end

  test "creates a draft bundle: index.html is the document with the canonical injected, the rest are files at their paths" do
    result = CreateExplorableTool.new.call(title: "Hotwire, explored", files: FILES)

    explorable = Explorable.find(result[:id])
    assert explorable.draft?
    assert_equal "hotwire-explored", result[:slug]
    assert_equal "draft", result[:status]
    assert_equal %w[ index.html decks/10-drive.html shared/style.css ], result[:files]
    assert_nil result[:warnings]
    assert_nil result[:missing_references]
    assert_includes result[:edit_url], "/writing/explorables/hotwire-explored/edit"
    assert_includes result[:message], "3 files"

    assert_includes explorable.raw_html, %(<link rel="canonical" href="https://#{Setting.current.production_host}/hotwire-explored/">)
    assert_equal DECK, explorable.assets.find_by(path: "decks/10-drive.html").content
  end

  test "relative paths in index.html are not warned about — they're the point — but ones nothing answers are" do
    files = FILES.reject { |file| file["path"] == "shared/style.css" }
    result = CreateExplorableTool.new.call(title: "Hotwire", slug: "hotwire", files: files)

    assert_equal %w[ shared/style.css ], result[:missing_references]
    assert_equal 1, result[:warnings].size
    assert_match(/1 relative reference won't resolve.*shared\/style\.css/, result[:warnings].first)
  end

  test "a bundle without index.html is refused" do
    result = CreateExplorableTool.new.call(title: "X", files: FILES.drop(1))
    assert_match(/no index\.html/, result[:error])
    assert_equal 0, Explorable.count
  end

  test "an index.html without a title is refused before anything is stored" do
    files = [ { "path" => "index.html", "content" => "<!DOCTYPE html><html><head></head><body>x</body></html>" } ]
    result = CreateExplorableTool.new.call(title: "X", files: files)
    assert_match(/no <title>/, result[:error])
    assert_equal 0, Explorable.count
  end

  test "a bad file path rolls the whole bundle back, naming the file" do
    files = FILES + [ { "path" => "../escape.css", "content" => "x" } ]
    result = CreateExplorableTool.new.call(title: "X", files: files)

    assert_match(/escape\.css.*plain relative path/, result[:error])
    assert_equal 0, Explorable.count
    assert_equal 0, Explorable::Asset.count
  end

  test "binary files arrive base64-encoded and are stored as bytes with their real type" do
    png = "\x89PNG\r\n\x1a\n".b
    files = FILES + [ { "path" => "img/pixel.png", "content" => Base64.strict_encode64(png), "encoding" => "base64" } ]
    result = CreateExplorableTool.new.call(title: "X", files: files)

    asset = Explorable.find(result[:id]).assets.find_by(path: "img/pixel.png")
    assert_equal png, asset.content.b
    assert_equal "image/png", asset.content_type
  end

  test "a duplicated path and bad base64 are named" do
    assert_match(/more than once: a\.css/, CreateExplorableTool.new.call(title: "X", files: FILES + [ { "path" => "a.css", "content" => "1" }, { "path" => "./a.css", "content" => "2" } ])[:error])
    assert_match(/isn't valid base64/, CreateExplorableTool.new.call(title: "X", files: FILES + [ { "path" => "a.png", "content" => "not base 64!", "encoding" => "base64" } ])[:error])
  end
end
