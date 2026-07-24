require "test_helper"

class UpdateTagToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, UpdateTagTool.new.call(slug: "chronicles", name: "X")
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::TAG_NOT_FOUND, UpdateTagTool.new.call(slug: "nope", name: "X")
  end

  test "updates name and description without a warning" do
    result = UpdateTagTool.new.call(slug: "chronicles", name: "Chronicles", description: "Diary entries")

    tag = tags(:chronicles).reload
    assert_equal "Chronicles", tag.name
    assert_equal "Diary entries", tag.description
    assert_nil result[:warning]
  end

  test "renaming the slug warns about the 404" do
    result = UpdateTagTool.new.call(slug: "chronicles", new_slug: "diaries")

    assert_equal "diaries", result[:slug]
    assert_equal "diaries", tags(:chronicles).reload.slug
    assert_includes result[:warning], "404"
  end
end
