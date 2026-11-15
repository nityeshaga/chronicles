require "test_helper"

class AddCommentToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, AddCommentTool.new.call(doc: posts(:doc).id, body: "x")
  end

  test "answers a thread, signed as the agent" do
    result = nil
    assert_difference -> { comments(:advisor).replies.count }, 1 do
      result = AddCommentTool.new.call(doc: posts(:doc).id, body: "Swapped it for the five questions.", reply_to: comments(:advisor).id)
    end

    assert_equal comments(:advisor).id, result[:id]
    assert_equal "Swapped it for the five questions.", result[:comments].last[:body]
    assert_equal "Luo", result[:comments].last[:author]
  end

  test "opens a thread pinned to a passage" do
    result = AddCommentTool.new.call(doc: posts(:doc).id, body: "Why three?", quote: "next three tutorials")

    thread = Comment.find(result[:id])
    assert thread.thread?
    assert_equal "next three tutorials", thread.quote
    assert_equal true, result[:quote_found]
  end

  test "opens a thread about the doc as a whole" do
    result = AddCommentTool.new.call(doc: posts(:doc).id, body: "Overall this reads well.", author: "Oracle")

    assert_nil Comment.find(result[:id]).quote
    assert_equal "Oracle", result[:comments].first[:author]
    assert_not result.key?(:quote_found)
  end

  test "refuses a quote the doc doesn't contain rather than leaving an orphan" do
    assert_no_difference -> { Comment.count } do
      result = AddCommentTool.new.call(doc: posts(:doc).id, body: "Hm.", quote: "<p>Think like a PhD advisor")
      assert_includes result[:error], "isn't in the doc"
    end
  end

  test "a reply carries no quote of its own" do
    result = AddCommentTool.new.call(doc: posts(:doc).id, body: "x", reply_to: comments(:advisor).id, quote: "syllabus")
    assert_includes result[:error], "reply"
  end

  test "an unknown thread or doc is an error, not an exception" do
    assert_equal ToolErrors::COMMENT_NOT_FOUND, AddCommentTool.new.call(doc: posts(:doc).id, body: "x", reply_to: 0)
    assert_equal ToolErrors::COMMENT_NOT_FOUND, AddCommentTool.new.call(doc: posts(:doc).id, body: "x", reply_to: comments(:advisor_reply).id)
    assert_equal ToolErrors::DOC_NOT_FOUND, AddCommentTool.new.call(doc: posts(:draft).id, body: "x")
  end
end
