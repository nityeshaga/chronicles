require "test_helper"

class CreatePostToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, CreatePostTool.new.call(title: "X")
  end

  test "always creates a draft, auto-slugging from the title" do
    result = CreatePostTool.new.call(title: "Hello World", body: "<p>Hi</p>")

    post = Post.find(result[:id])
    assert post.draft?
    assert_equal "draft", result[:status]
    assert_equal "hello-world", result[:slug]
    assert_equal "hello-world", post.slug
    assert_includes post.body.to_s, "<p>Hi</p>"
    assert_includes result[:edit_url], "/writing/posts/hello-world/edit"
    assert_includes result[:message], "publish_post"
  end

  test "honors an explicit slug" do
    result = CreatePostTool.new.call(title: "Hello World", slug: "custom-path")
    assert_equal "custom-path", result[:slug]
  end

  test "finds or creates tags by name" do
    assert_nil Tag.find_by(name: "brand-new")

    result = CreatePostTool.new.call(title: "Tagged", tags: [ "chronicles", "brand-new" ])
    post = Post.find(result[:id])

    assert_equal %w[ brand-new chronicles ], post.tags.map(&:name).sort
    assert_equal tags(:chronicles).id, post.tags.find { |t| t.name == "chronicles" }.id
    assert_equal "brand-new", Tag.find_by(name: "brand-new").slug
  end

  test "creates a page when kind is page" do
    result = CreatePostTool.new.call(title: "Colophon", kind: "page")
    post = Post.find(result[:id])

    assert post.is_a?(Page)
    assert_includes result[:edit_url], "/writing/pages/colophon/edit"
  end

  test "rejects an unknown kind" do
    assert_equal ToolErrors::INVALID_KIND, CreatePostTool.new.call(title: "X", kind: "banana")
  end

  test "squishing of the title is left to the model" do
    result = CreatePostTool.new.call(title: "  Spaced   Out  ")
    assert_equal "Spaced Out", Post.find(result[:id]).title
  end
end
