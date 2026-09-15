require "test_helper"

class ListShipsToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, ListShipsTool.new.call
  end

  test "everything newest first, with every field the agent needs" do
    result = ListShipsTool.new.call

    assert_equal %i[ drafted phone hotwire essay clock markdown cc ].map { |name| ships(name).id }, result[:ships].map { |s| s[:id] }
    assert_equal 7, result[:total_count]

    phone = result[:ships].find { |s| s[:id] == ships(:phone).id }
    assert_equal 19, phone[:number]
    assert_equal "published", phone[:status]
    assert_equal "2026-09-11", phone[:shipped_on]
    assert_equal "tool", phone[:kind]
    assert_equal "together", phone[:built_by]
    assert_equal "https://github.com/nityeshaga/claude-home-base", phone[:check_it_out_url]
    assert_equal "2098484853939597670", phone[:x_status_id]
    assert_nil phone[:media_kind]

    essay = result[:ships].find { |s| s[:id] == ships(:essay).id }
    assert_equal "a-published-post", essay[:post]
    assert_equal "https://#{Setting.current.production_host}/a-published-post/", essay[:check_it_out_url]
    assert_equal :cover, essay[:media_kind]
  end

  test "filters by status and kind, and refuses unknown values" do
    assert_equal [ ships(:drafted).id ], ListShipsTool.new.call(status: "draft")[:ships].map { |s| s[:id] }
    assert_equal [ ships(:essay).id ], ListShipsTool.new.call(kind: "chronicle")[:ships].map { |s| s[:id] }
    assert_equal 1, ListShipsTool.new.call(limit: 1)[:ships].size

    assert_includes ListShipsTool.new.call(status: "live")[:error], "status"
    assert_includes ListShipsTool.new.call(kind: "gadget")[:error], "kind"
  end
end
