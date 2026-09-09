require "test_helper"

class UpdateExplorableToolTest < ActiveSupport::TestCase
  INDEX = %(<!DOCTYPE html>\n<html lang="en"><head><title>Hotwire</title><meta name="description" content="x"><link rel="stylesheet" href="shared/style.css"></head><body><a href="decks/10-drive.html">go</a></body></html>\n)

  setup do
    Thread.current[:mcp_current_user] = users(:nityesh)
    result = CreateExplorableTool.new.call(title: "Hotwire", slug: "hotwire", files: [
      { "path" => "index.html", "content" => INDEX },
      { "path" => "shared/style.css", "content" => "v1" },
      { "path" => "decks/10-drive.html", "content" => "<html><head><title>d</title></head></html>" }
    ])
    @explorable = Explorable.find(result[:id])
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication and the right kind" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, UpdateExplorableTool.new.call(id_or_slug: "hotwire", title: "X")
    Thread.current[:mcp_current_user] = users(:nityesh)
    assert_equal ToolErrors::POST_NOT_FOUND, UpdateExplorableTool.new.call(id_or_slug: "nope", title: "X")
    assert_equal ToolErrors::NOT_AN_EXPLORABLE, UpdateExplorableTool.new.call(id_or_slug: posts(:html_page).slug, title: "X")
    assert_equal ToolErrors::IS_AN_EXPLORABLE, UpdateHtmlPageTool.new.call(id_or_slug: "hotwire", title: "X")
  end

  test "sent files replace or add; everything else stays" do
    result = UpdateExplorableTool.new.call(id_or_slug: "hotwire", files: [
      { "path" => "shared/style.css", "content" => "v2" },
      { "path" => "decks/20-frames.html", "content" => "<html><head><title>f</title></head></html>" }
    ])

    assert_equal %w[ files ], result[:changed]
    assert_equal %w[ index.html decks/10-drive.html decks/20-frames.html shared/style.css ], result[:files]
    assert_equal "v2", @explorable.assets.find_by(path: "shared/style.css").content
    assert_nil result[:warnings]
  end

  test "index.html in files replaces the document and is re-screened, canonical kept" do
    result = UpdateExplorableTool.new.call(id_or_slug: "hotwire", files: [ { "path" => "index.html", "content" => INDEX.sub("<body>", "<body>new ") } ])
    assert_equal %w[ files ], result[:changed]
    html = @explorable.reload.raw_html
    assert_includes html, "<body>new "
    assert_equal 1, html.scan("rel=\"canonical\"").size
  end

  test "remove_paths deletes files; an unknown path changes nothing" do
    result = UpdateExplorableTool.new.call(id_or_slug: "hotwire", remove_paths: [ "shared/style.css" ])
    assert_equal %w[ removed ], result[:changed]
    assert_equal %w[ shared/style.css ], result[:missing_references]
    assert_match(/won't resolve/, result[:warnings].first)

    result = UpdateExplorableTool.new.call(id_or_slug: "hotwire", files: [ { "path" => "a.css", "content" => "" } ], remove_paths: [ "decks/nope.html" ])
    assert_match(/nothing was changed: decks\/nope\.html/, result[:error])
    assert_nil @explorable.assets.find_by(path: "a.css")

    assert_match(/index\.html can't be removed/, UpdateExplorableTool.new.call(id_or_slug: "hotwire", remove_paths: [ "index.html" ])[:error])
  end

  test "renaming a published explorable's slug rewrites the canonical and warns" do
    @explorable.publish_now
    result = UpdateExplorableTool.new.call(id_or_slug: "hotwire", slug: "hotwire-2")

    assert_equal %w[ slug ], result[:changed]
    assert_includes @explorable.reload.raw_html, "/hotwire-2/\">"
    assert_match(%r{/hotwire/ now 404s}, result[:warnings].join)
    assert_equal "https://#{Setting.current.production_host}/hotwire-2/", result[:url]
  end

  test "get_post and list_posts know the kind and the files" do
    got = GetPostTool.new.call(id_or_slug: "hotwire")
    assert_equal "explorable", got[:kind]
    assert_equal %w[ decks/10-drive.html shared/style.css ], got[:files]
    assert_includes got[:body], "<title>Hotwire</title>"

    listed = ListPostsTool.new.call(kind: "explorable")
    assert_equal [ "hotwire" ], listed[:posts].map { |post| post[:slug] }
    assert_empty ListPostsTool.new.call(kind: "html_page")[:posts].select { |post| post[:slug] == "hotwire" }
  end
end
