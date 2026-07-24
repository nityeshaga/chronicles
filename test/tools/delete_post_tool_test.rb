require "test_helper"

class DeletePostToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, DeletePostTool.new.call(id_or_slug: "a-draft-post", confirm: true)
  end

  test "without confirm it previews and deletes nothing" do
    post = posts(:draft)
    result = DeletePostTool.new.call(id_or_slug: post.slug, confirm: false)

    assert result[:requires_confirmation]
    assert_equal post.slug, result[:would_delete][:slug]
    assert_equal "article", result[:would_delete][:kind]
    assert Post.exists?(post.id)
  end

  test "with confirm it destroys and echoes what was deleted" do
    post = posts(:draft)
    result = DeletePostTool.new.call(id_or_slug: post.slug, confirm: true)

    assert result[:success]
    assert_equal post.slug, result[:deleted][:slug]
    assert_not Post.exists?(post.id)
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::POST_NOT_FOUND, DeletePostTool.new.call(id_or_slug: "nope", confirm: true)
  end
end
