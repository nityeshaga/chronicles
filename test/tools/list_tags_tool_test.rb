require "test_helper"

class ListTagsToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, ListTagsTool.new.call
  end

  test "lists every tag with counts" do
    result = ListTagsTool.new.call
    slugs = result[:tags].map { |t| t[:slug] }

    assert_equal Tag.count, result[:tags].size
    assert_includes slugs, "chronicles"

    chronicles = result[:tags].find { |t| t[:slug] == "chronicles" }
    assert_equal 1, chronicles[:published_post_count]
    assert_equal 1, chronicles[:total_post_count]

    ai = result[:tags].find { |t| t[:slug] == "ai" }
    assert_equal 0, ai[:total_post_count]
  end
end
