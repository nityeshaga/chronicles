require "test_helper"

class ResolveNoteToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, ResolveNoteTool.new.call(id: notes(:excerpt).id, resolution: "x")
  end

  test "resolves with the line that will show on the page" do
    result = ResolveNoteTool.new.call(id: notes(:excerpt).id, resolution: "Trimmed to two sentences.")
    assert_equal "Trimmed to two sentences.", result[:resolution]
    assert notes(:excerpt).reload.resolved?
    assert_equal "Trimmed to two sentences.", notes(:excerpt).resolution
  end

  test "an unknown id is an error, not an exception" do
    assert ResolveNoteTool.new.call(id: 0, resolution: "x")[:error].present?
  end
end
