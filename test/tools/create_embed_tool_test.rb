require "test_helper"

class CreateEmbedToolTest < ActiveSupport::TestCase
  setup do
    Thread.current[:mcp_current_user] = users(:nityesh)
    @tool = CreateEmbedTool.new
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, @tool.call(url: "https://x.com/a/status/1")
  end

  test "turns a tweet URL into a kg-embed-card figure" do
    result = @tool.call(url: "https://twitter.com/nityeshaga/status/123456")

    assert_includes result[:figure_html], "kg-embed-card"
    assert_includes result[:figure_html], "twitter-tweet"
    assert_includes result[:message], "body_patches"
  end

  test "turns a YouTube URL into an iframe embed" do
    result = @tool.call(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")

    assert_includes result[:figure_html], "youtube.com/embed/dQw4w9WgXcQ"
  end

  test "returns a recovery-oriented error for an unsupported URL" do
    result = @tool.call(url: "https://example.com/nope")

    assert result[:error]
    assert_includes result[:error], "upload_image"
  end
end
