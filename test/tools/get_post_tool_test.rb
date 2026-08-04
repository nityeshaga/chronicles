require "test_helper"

class GetPostToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    @post = posts(:published)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, GetPostTool.new.call(id_or_slug: @post.slug)
  end

  test "fetches a post by slug with all authoring fields" do
    result = GetPostTool.new.call(id_or_slug: @post.slug)

    assert_equal @post.id, result[:id]
    assert_equal @post.slug, result[:slug]
    assert_equal @post.title, result[:title]
    assert_equal "article", result[:kind]
    assert_equal "published", result[:status]
    assert_equal @post.feature_image, result[:feature_image]
    assert_equal @post.feature_image_caption, result[:feature_image_caption]
    assert_equal @post.meta_description, result[:meta_description]
    assert_equal @post.published_at, Time.iso8601(result[:published_at])
    assert_includes result[:body], "published"
    assert_not result[:body_truncated]
    assert_equal result[:body].length, result[:body_total_length]
  end

  test "fetches a post by numeric id" do
    result = GetPostTool.new.call(id_or_slug: @post.id)
    assert_equal @post.slug, result[:slug]
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::POST_NOT_FOUND, GetPostTool.new.call(id_or_slug: "does-not-exist")
    assert_equal ToolErrors::POST_NOT_FOUND, GetPostTool.new.call(id_or_slug: 999_999)
  end

  test "returns the raw stored fragment, not the layout-wrapped render" do
    result = GetPostTool.new.call(id_or_slug: @post.slug)

    assert_equal @post.body.body.to_html, result[:body]
    assert_not_includes result[:body], "trix-content"
    assert_equal result[:body].length, result[:body_total_length]
  end

  test "windows the body with offset and limit and flags truncation" do
    result = GetPostTool.new.call(id_or_slug: @post.slug, body_limit: 5)

    full = @post.body.body.to_html
    assert_equal full[0, 5], result[:body]
    assert_equal full.length, result[:body_total_length]
    assert result[:body_truncated]

    tail = GetPostTool.new.call(id_or_slug: @post.slug, body_offset: 5, body_limit: 20_000)
    assert_equal full[5..], tail[:body]
    assert_not tail[:body_truncated]
    assert_equal 5, tail[:body_offset]
  end

  test "exposes a public url only when published" do
    published = GetPostTool.new.call(id_or_slug: @post.slug)
    assert_equal "https://#{Setting.current.production_host}/a-published-post/", published[:url]

    draft = GetPostTool.new.call(id_or_slug: posts(:draft).slug)
    assert_nil draft[:url]

    scheduled = GetPostTool.new.call(id_or_slug: posts(:scheduled).slug)
    assert_nil scheduled[:url]
    assert_equal "scheduled", scheduled[:status]
  end

  test "reports page kind" do
    result = GetPostTool.new.call(id_or_slug: "about")
    assert_equal "page", result[:kind]
  end

  test "an html page's body window is its stored document" do
    page = posts(:html_page)
    result = GetPostTool.new.call(id_or_slug: "hands-on-deck")

    assert_equal "html_page", result[:kind]
    assert_equal page.raw_html, result[:body]
    assert_equal page.raw_html.length, result[:body_total_length]
    assert_not result[:body_truncated]

    windowed = GetPostTool.new.call(id_or_slug: "hands-on-deck", body_offset: 10, body_limit: 25)
    assert_equal page.raw_html[10, 25], windowed[:body]
    assert windowed[:body_truncated]
  end
end
