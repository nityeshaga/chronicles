require "test_helper"

class ResolveCommentToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, ResolveCommentTool.new.call(id: comments(:advisor).id)
  end

  test "says what changed in the thread, then resolves it" do
    result = ResolveCommentTool.new.call(id: comments(:advisor).id, reply: "Replaced with the five questions.")

    assert comments(:advisor).reload.resolved?
    assert_equal "Replaced with the five questions.", comments(:advisor).replies.last.body
    assert_equal "Luo", comments(:advisor).replies.last.author_name
    assert result[:resolved_at].present?
    assert_equal 3, result[:comments].size
  end

  test "resolves without a word when there is nothing to add" do
    assert_no_difference -> { Comment.count } do
      ResolveCommentTool.new.call(id: comments(:advisor).id)
    end
    assert comments(:advisor).reload.resolved?
  end

  test "resolving twice changes nothing the second time" do
    stamp = comments(:settled).resolved_at

    assert_no_difference -> { Comment.count } do
      ResolveCommentTool.new.call(id: comments(:settled).id, reply: "Again.")
    end
    assert_equal stamp, comments(:settled).reload.resolved_at
  end

  test "a reply or an unknown id is an error, not an exception" do
    assert_equal ToolErrors::COMMENT_NOT_FOUND, ResolveCommentTool.new.call(id: comments(:advisor_reply).id)
    assert_equal ToolErrors::COMMENT_NOT_FOUND, ResolveCommentTool.new.call(id: 0)
  end
end
