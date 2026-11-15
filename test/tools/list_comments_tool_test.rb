require "test_helper"

class ListCommentsToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, ListCommentsTool.new.call(doc: posts(:doc).id)
  end

  test "open threads by default, each with its quote and every reply in order" do
    result = ListCommentsTool.new.call(doc: posts(:doc).id)

    assert_equal "Teaching context", result[:doc][:title]
    assert_includes result[:doc][:edit_url], "/writing/docs/#{posts(:doc).id}/edit"
    assert_equal [ comments(:advisor).id ], result[:threads].map { |thread| thread[:id] }

    thread = result[:threads].first
    assert_equal "Think like a PhD advisor", thread[:quote]
    assert_equal true, thread[:quote_found]
    assert_equal [ "Nityesh Agarwal", "Luo" ], thread[:comments].map { |comment| comment[:author] }
    assert_not thread.key?(:resolved_at)
  end

  test "resolved and all" do
    assert_equal [ comments(:settled).id ], ListCommentsTool.new.call(doc: posts(:doc).id, status: "resolved")[:threads].map { |t| t[:id] }
    assert_equal 2, ListCommentsTool.new.call(doc: posts(:doc).id, status: "all")[:threads].size
    assert ListCommentsTool.new.call(doc: posts(:doc).id, status: "closed")[:error].present?
  end

  test "says when a thread's passage has been rewritten" do
    posts(:doc).update!(body: "<p>Plan like an advisor would.</p>")

    thread = ListCommentsTool.new.call(doc: posts(:doc).id)[:threads].first
    assert_equal false, thread[:quote_found]
    assert_equal "Think like a PhD advisor", thread[:quote]
  end

  test "finds the doc by slug, and only a doc" do
    assert_equal 1, ListCommentsTool.new.call(doc: "teaching-context")[:threads].size
    assert_equal ToolErrors::DOC_NOT_FOUND, ListCommentsTool.new.call(doc: posts(:draft).id)
    assert_equal ToolErrors::DOC_NOT_FOUND, ListCommentsTool.new.call(doc: 0)
  end
end
