require "test_helper"

class PublishShipToolTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, PublishShipTool.new.call(id: ships(:drafted).id)
  end

  test "publishes a draft and mints the next number" do
    result = PublishShipTool.new.call(id: ships(:drafted).id)

    assert_equal "published", result[:status]
    assert_equal 20, result[:number]
    assert_includes result[:message], "№ 020"
    assert ships(:drafted).reload.published?
    assert_includes Ship.log, ships(:drafted)
  end

  test "re-publishing keeps the number" do
    result = PublishShipTool.new.call(id: ships(:phone).id)
    assert_equal 19, result[:number]
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::SHIP_NOT_FOUND, PublishShipTool.new.call(id: 0)
  end
end
