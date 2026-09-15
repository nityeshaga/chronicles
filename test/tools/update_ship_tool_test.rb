require "test_helper"

class UpdateShipToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, UpdateShipTool.new.call(id: ships(:phone).id, title: "X")
  end

  test "changes only what is passed and reports it" do
    ship = ships(:phone)
    result = UpdateShipTool.new.call(id: ship.id, blurb: "Shorter.", shipped_on: "2026-09-12", kind: "app")

    ship.reload
    assert_equal "Shorter.", ship.blurb
    assert_equal Date.new(2026, 9, 12), ship.shipped_on
    assert_equal "app", ship.kind
    assert_equal "Luo can take a phone call now.", ship.title
    assert_equal 19, ship.number
    assert_equal %i[ kind shipped_on blurb ].sort, result[:changed].sort
  end

  test "links posts by slug and refuses one that does not exist" do
    ship = ships(:phone)
    result = UpdateShipTool.new.call(id: ship.id, how_built_post: "a-draft-post")
    assert_equal posts(:draft), ship.reload.how_built_post
    assert_equal "a-draft-post", result[:how_built_post]

    result = UpdateShipTool.new.call(id: ship.id, post: "nope")
    assert_includes result[:error], "post 'nope' not found"
  end

  test "not found, and the model's word on a bad value" do
    assert_equal ToolErrors::SHIP_NOT_FOUND, UpdateShipTool.new.call(id: 0, title: "X")
    assert_includes UpdateShipTool.new.call(id: ships(:phone).id, built_by: "robot")[:error], "Built by"
  end
end
