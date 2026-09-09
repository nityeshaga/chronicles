require "test_helper"

class ExplorableTest < ActiveSupport::TestCase
  INDEX = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head><title>Hotwire, explored</title><link rel="stylesheet" href="shared/style.css"></head>
    <body><a href="decks/10-drive.html">Start</a><a href="decks/">Decks</a><img src="/absolute.png"><a href="#top">top</a></body>
    </html>
  HTML

  DECK = %(<!DOCTYPE html><html><head><title>Drive</title><link rel="stylesheet" href="../shared/style.css"><script src="../shared/engine.js"></script></head><body><a href="../index.html">Home</a><a href="20-frames.html">Next</a></body></html>)

  setup do
    @explorable = Explorable.create!(title: "Hotwire", slug: "hotwire", raw_html: INDEX)
  end

  test "write_files stores index.html as the document and everything else as assets at their paths" do
    @explorable.write_files([
      { path: "index.html", content: INDEX.sub("explored", "explored again") },
      { path: "shared/style.css", content: "body{}" },
      { path: "decks/10-drive.html", content: DECK }
    ])

    assert_includes @explorable.reload.raw_html, "explored again"
    assert_equal %w[ decks/10-drive.html shared/style.css ], @explorable.assets.order(:path).pluck(:path)
    assert_equal "text/css", @explorable.assets.find_by(path: "shared/style.css").content_type
    assert_equal "text/html", @explorable.assets.find_by(path: "decks/10-drive.html").content_type
  end

  test "writing the same path again replaces it rather than adding a second" do
    @explorable.write_files([ { path: "shared/style.css", content: "v1" } ])
    @explorable.write_files([ { path: "shared/style.css", content: "v2" } ])

    assert_equal 1, @explorable.assets.count
    assert_equal "v2", @explorable.assets.sole.content
  end

  test "asset_at answers a file, or a directory's index" do
    @explorable.write_files([ { path: "decks/index.html", content: DECK }, { path: "decks/10-drive.html", content: DECK } ])

    assert_equal "decks/10-drive.html", @explorable.asset_at("decks/10-drive.html").path
    assert_equal "decks/index.html", @explorable.asset_at("decks").path
    assert_nil @explorable.asset_at("decks/nope.html")
  end

  test "missing_references lists every relative link across the bundle's HTML that no file answers" do
    @explorable.write_files([ { path: "decks/10-drive.html", content: DECK } ])

    # Absolute, anchor-only and present paths are fine; the rest are named once each.
    assert_equal %w[ shared/style.css decks shared/engine.js decks/20-frames.html ], @explorable.missing_references

    @explorable.write_files([ { path: "shared/style.css", content: "" }, { path: "shared/engine.js", content: "" }, { path: "decks/index.html", content: "<html><head><title>d</title></head></html>" } ])
    assert_equal %w[ decks/20-frames.html ], @explorable.missing_references
  end

  test "a path that escapes the bundle or hides is refused" do
    %w[ ../etc/passwd /abs.css .hidden a/./b a//b ].each do |path|
      asset = @explorable.assets.build(path: path, content: "x")
      assert_not asset.valid?, path
    end
    assert @explorable.assets.build(path: "decks/10-drive.html", content: "x").valid?
    assert @explorable.assets.build(path: "fonts/inter-v1.2.woff2", content: "x").valid?
  end

  test "an empty file is allowed; a nil one isn't" do
    assert @explorable.assets.build(path: ".nojekyll".delete_prefix("."), content: "").valid?
    assert_not @explorable.assets.build(path: "x.txt", content: nil).valid?
  end

  test "deleting the explorable takes its files with it" do
    @explorable.write_files([ { path: "a.css", content: "" } ])
    assert_difference -> { Explorable::Asset.count }, -1 do
      @explorable.destroy
    end
  end

  test "it is an HTML page for everything the rest of the site asks" do
    assert_kind_of HtmlPage, @explorable
    assert_equal "explorable", @explorable.dashboard_bucket
    assert_not Explorable.new(title: "x", raw_html: "<div>fragment</div>").valid?
  end
end
