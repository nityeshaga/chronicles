require "test_helper"

# A doc has no tools of its own for the things a post already has tools for: it is a kind.
class DocToolsTest < ActiveSupport::TestCase
  setup { Thread.current[:mcp_current_user] = users(:nityesh) }
  teardown { Thread.current[:mcp_current_user] = nil }

  test "create_post makes a doc, addressed by id" do
    result = CreatePostTool.new.call(title: "Launch plan", kind: "doc", body: "<p>Step one.</p>")

    doc = Doc.find(result[:id])
    assert doc.draft?
    assert_includes doc.body.to_s, "Step one."
    assert_includes result[:edit_url], "/writing/docs/#{doc.id}/edit"
  end

  test "an unknown kind names the three it could have been" do
    assert_equal ToolErrors::INVALID_KIND, CreatePostTool.new.call(title: "X", kind: "memo")
    assert_includes ToolErrors::INVALID_KIND[:error], "doc"
  end

  test "get_post reads a doc and says what is waiting in its margin" do
    result = GetPostTool.new.call(id_or_slug: posts(:doc).id)

    assert_equal "doc", result[:kind]
    assert_equal "private", result[:status]
    assert_equal 1, result[:open_comments]
    assert_includes result[:body], "PhD advisor"
    assert_not GetPostTool.new.call(id_or_slug: posts(:draft).id).key?(:open_comments)
  end

  test "update_post patches a doc's body" do
    result = UpdatePostTool.new.call(id_or_slug: posts(:doc).id, body_patches: [ { "old" => "not a syllabus", "new" => "not a textbook" } ])

    assert_equal [ "body" ], result[:changed]
    assert_includes posts(:doc).reload.body.to_s, "not a textbook"
    assert_includes result[:edit_url], "/writing/docs/"
  end

  test "list_posts filters to docs and hands back where to open each" do
    result = ListPostsTool.new.call(kind: "doc")

    assert_equal [ posts(:doc).id ], result[:posts].map { |post| post[:id] }
    assert_includes result[:posts].first[:edit_url], "/writing/docs/#{posts(:doc).id}/edit"
    assert_not ListPostsTool.new.call(kind: "article")[:posts].first.key?(:edit_url)
    # A doc is nobody's draft: it isn't on its way to being published.
    assert_not_includes ListPostsTool.new.call(status: "draft")[:posts].map { |post| post[:id] }, posts(:doc).id
  end

  test "publish_post refuses a doc and leaves it private" do
    result = PublishPostTool.new.call(id_or_slug: posts(:doc).id)

    assert_includes result[:error], "private"
    assert posts(:doc).reload.draft?
  end

  test "a doc becomes a draft post by changing its kind, and a live post can't become a doc" do
    UpdatePostTool.new.call(id_or_slug: posts(:doc).id, kind: "article")
    assert_equal "Post", Post.find(posts(:doc).id).type
    assert Post.find(posts(:doc).id).draft?

    result = UpdatePostTool.new.call(id_or_slug: posts(:published).id, kind: "doc")
    assert_includes result[:error], "private"
    assert_equal "Post", Post.find(posts(:published).id).type
  end
end
