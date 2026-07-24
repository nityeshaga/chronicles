require "test_helper"

class UnpublishPostToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, UnpublishPostTool.new.call(id_or_slug: "a-published-post")
  end

  test "reverts a published post to draft" do
    result = UnpublishPostTool.new.call(id_or_slug: "a-published-post")

    assert_equal "draft", result[:status]
    assert posts(:published).reload.draft?
    assert_includes result[:note], "cancelled"
  end

  test "clears a pending future schedule" do
    post = posts(:scheduled)
    assert post.scheduled?

    result = UnpublishPostTool.new.call(id_or_slug: post.slug)

    assert_equal "draft", result[:status]
    assert_nil post.reload.published_at
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::POST_NOT_FOUND, UnpublishPostTool.new.call(id_or_slug: "nope")
  end
end
