require "test_helper"

class ListNotesToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, ListNotesTool.new.call
  end

  test "open notes by default, with everything the agent needs to act" do
    result = ListNotesTool.new.call
    ids = result[:notes].map { |n| n[:id] }
    assert_includes ids, notes(:excerpt).id
    assert_not_includes ids, notes(:image).id

    note = result[:notes].find { |n| n[:id] == notes(:excerpt).id }
    assert_equal "/about/", note[:path]
    assert_equal "https://#{Setting.current.production_host}/about/", note[:url]
    assert_equal notes(:excerpt).selector, note[:selector]
    assert_equal "I write about building", note[:snippet]
    assert_equal "This runs long. Two sentences.", note[:body]
    assert_nil note[:resolution]
  end

  test "resolved, all, and a path filter" do
    resolved = ListNotesTool.new.call(status: "resolved")[:notes]
    assert_equal [ notes(:image).id ], resolved.map { |n| n[:id] }
    assert_equal "Swapped via update_post.", resolved.first[:resolution]

    assert_equal Note.count, ListNotesTool.new.call(status: "all")[:notes].size
    assert_equal [ notes(:homepage).id ], ListNotesTool.new.call(path: "/")[:notes].map { |n| n[:id] }
    assert ListNotesTool.new.call(status: "sideways")[:error].present?
  end
end
