require "test_helper"

class ListPostsToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, ListPostsTool.new.call
  end

  test "lists posts and pages with metadata but no bodies" do
    result = ListPostsTool.new.call

    slugs = result[:posts].map { |p| p[:slug] }
    assert_includes slugs, "a-published-post"
    assert_includes slugs, "about"
    assert_equal result[:posts].size, result[:total_count]
    assert result[:posts].none? { |p| p.key?(:body) }
  end

  test "filters by published status includes pages" do
    result = ListPostsTool.new.call(status: "published")
    slugs = result[:posts].map { |p| p[:slug] }

    assert_includes slugs, "a-published-post"
    assert_includes slugs, "about"
    assert_not_includes slugs, "a-draft-post"
    assert_not_includes slugs, "a-scheduled-post"
  end

  test "draft status excludes scheduled drafts" do
    result = ListPostsTool.new.call(status: "draft")
    slugs = result[:posts].map { |p| p[:slug] }

    assert_equal [ "a-draft-post" ], slugs
  end

  test "scheduled status returns future-dated drafts with derived status" do
    result = ListPostsTool.new.call(status: "scheduled")

    assert_equal [ "a-scheduled-post" ], result[:posts].map { |p| p[:slug] }
    assert_equal "scheduled", result[:posts].first[:status]
  end

  test "filters by kind" do
    pages = ListPostsTool.new.call(kind: "page")
    assert_equal [ "about" ], pages[:posts].map { |p| p[:slug] }
    assert_equal "page", pages[:posts].first[:kind]

    articles = ListPostsTool.new.call(kind: "article")
    assert_not_includes articles[:posts].map { |p| p[:slug] }, "about"
    assert articles[:posts].all? { |p| p[:kind] == "article" }
  end

  test "html pages are their own kind, not lumped in with pages" do
    html_pages = ListPostsTool.new.call(kind: "html_page")
    assert_equal [ "hands-on-deck" ], html_pages[:posts].map { |p| p[:slug] }
    assert_equal "html_page", html_pages[:posts].first[:kind]

    assert_not_includes ListPostsTool.new.call(kind: "page")[:posts].map { |p| p[:slug] }, "hands-on-deck"

    unfiltered = ListPostsTool.new.call.dig(:posts)
    assert_equal "html_page", unfiltered.find { |p| p[:slug] == "hands-on-deck" }[:kind]
  end

  test "filters by tag slug" do
    result = ListPostsTool.new.call(tag: "chronicles")

    assert_equal [ "a-published-post" ], result[:posts].map { |p| p[:slug] }
    assert_includes result[:posts].first[:tags], "chronicles"
  end

  test "unknown tag returns a recovery error" do
    assert_equal ToolErrors::TAG_NOT_FOUND, ListPostsTool.new.call(tag: "no-such-tag")
  end

  test "filters by case-insensitive title query" do
    result = ListPostsTool.new.call(query: "DRAFT")
    assert_equal [ "a-draft-post" ], result[:posts].map { |p| p[:slug] }
  end

  test "paginates with limit offset and reports has_more" do
    first = ListPostsTool.new.call(limit: 1, offset: 0)

    assert_equal 1, first[:posts].size
    assert first[:has_more]
    assert_equal 1, first[:next_offset]
    assert_operator first[:total_count], :>, 1

    last = ListPostsTool.new.call(limit: 100, offset: 0)
    assert_not last[:has_more]
    assert_nil last[:next_offset]
  end

  test "clamps limit to the maximum" do
    result = ListPostsTool.new.call(limit: 5_000)
    assert_operator result[:posts].size, :<=, ListPostsTool::MAX_LIMIT
  end
end
