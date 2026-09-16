require "test_helper"

class CreateShipToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, CreateShipTool.new.call(title: "X", kind: "app", built_by: "luo")
  end

  test "always creates an unnumbered draft, dated today unless told otherwise" do
    result = CreateShipTool.new.call(title: "  A new   thing. ", kind: "app", built_by: "together", blurb: "Two lines.", prompt: "Do it.", x_status_id: "123")

    ship = Ship.find(result[:id])
    assert ship.draft?
    assert_nil ship.number
    assert_equal "A new thing.", ship.title
    assert_equal Date.current, ship.shipped_on
    assert_equal "Do it.", ship.prompt
    assert_equal "draft", result[:status]
    assert_includes result[:message], "publish_ship"

    dated = CreateShipTool.new.call(title: "Dated", kind: "skill", built_by: "luo", shipped_on: "2026-09-01")
    assert_equal Date.new(2026, 9, 1), Ship.find(dated[:id]).shipped_on
  end

  test "links the announced post and the how-built post by id or slug" do
    result = CreateShipTool.new.call(title: "Essay", kind: "chronicle", built_by: "nityesh", post: "a-published-post", how_built_post: posts(:draft).id)

    ship = Ship.find(result[:id])
    assert_equal posts(:published), ship.post
    assert_equal posts(:draft), ship.how_built_post
    assert_equal "a-published-post", result[:post]
    assert_equal "https://#{Setting.current.production_host}/a-published-post/", result[:check_it_out_url]
  end

  test "refuses an unknown post reference before saving anything" do
    assert_no_difference -> { Ship.count } do
      result = CreateShipTool.new.call(title: "Essay", kind: "chronicle", built_by: "nityesh", post: "nope")
      assert_includes result[:error], "post 'nope' not found"
    end
  end

  test "an unknown kind or builder comes back as the model's error" do
    result = CreateShipTool.new.call(title: "Odd", kind: "gadget", built_by: "luo")
    assert_includes result[:error], "Kind"

    result = CreateShipTool.new.call(title: "Odd", kind: "app", built_by: "robot")
    assert_includes result[:error], "Built by"
  end
end
