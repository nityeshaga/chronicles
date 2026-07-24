require "test_helper"

class UpdatePostToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, UpdatePostTool.new.call(id_or_slug: "a-draft-post", title: "X")
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::POST_NOT_FOUND, UpdatePostTool.new.call(id_or_slug: "nope", title: "X")
  end

  test "updates full fields and reports the changed names" do
    result = UpdatePostTool.new.call(id_or_slug: "a-draft-post", title: "New Title", excerpt: "New excerpt", meta_title: "MT")

    post = posts(:draft).reload
    assert_equal "New Title", post.title
    assert_equal "New excerpt", post.excerpt
    assert_equal "MT", post.meta_title
    assert_includes result[:changed], "title"
    assert_includes result[:changed], "excerpt"
    assert_includes result[:changed], "meta_title"
  end

  test "replaces the body wholesale" do
    result = UpdatePostTool.new.call(id_or_slug: "a-draft-post", body: "<p>Fresh</p>")
    assert_includes posts(:draft).reload.body.to_s, "<p>Fresh</p>"
    assert_includes result[:changed], "body"
  end

  test "applies a surgical body_patch" do
    result = UpdatePostTool.new.call(id_or_slug: "a-published-post", body_patches: [ { "old" => "published", "new" => "PUBLISHED" } ])

    assert_nil result[:error]
    assert_equal 1, result[:body_patches_applied]
    assert_equal "<p>The body of a <i>PUBLISHED</i> post.</p>", posts(:published).reload.body.body.to_html
  end

  test "repeated edits never nest the layout wrapper in stored content" do
    create = CreatePostTool.new.call(title: "Wrapper Check", body: "<p>alpha beta</p>")
    slug = create[:slug]

    UpdatePostTool.new.call(id_or_slug: slug, body_patches: [ { "old" => "alpha", "new" => "gamma" } ])
    UpdatePostTool.new.call(id_or_slug: slug, body_patches: [ { "old" => "beta", "new" => "delta" } ])

    raw = Post.find_by(slug: slug).body.body.to_html
    assert_not_includes raw, "trix-content"
    assert_equal "<p>gamma delta</p>", raw
  end

  test "get_post and update_post round-trip a patch with no drift" do
    create = CreatePostTool.new.call(title: "Round Trip", body: "<p>the quick brown fox</p>")
    slug = create[:slug]

    before = GetPostTool.new.call(id_or_slug: slug)[:body]
    assert_equal "<p>the quick brown fox</p>", before

    UpdatePostTool.new.call(id_or_slug: slug, body_patches: [ { "old" => before, "new" => "<p>the quick red fox</p>" } ])

    after = GetPostTool.new.call(id_or_slug: slug)[:body]
    assert_equal "<p>the quick red fox</p>", after
  end

  test "body_patches with zero matches errors, names the index, and changes nothing" do
    result = UpdatePostTool.new.call(id_or_slug: "a-published-post", body_patches: [ { "old" => "nonexistent", "new" => "x" } ])

    assert_includes result[:error], "Patch 0"
    assert_includes result[:error], "get_post"
    assert_includes posts(:published).reload.body.to_s, "published"
  end

  test "body_patches with multiple matches asks for more context" do
    post = Post.create!(title: "Dup", body: "<p>cat cat</p>")
    result = UpdatePostTool.new.call(id_or_slug: post.slug, body_patches: [ { "old" => "cat", "new" => "dog" } ])

    assert_includes result[:error], "more than once"
    assert_includes post.reload.body.to_s, "cat"
  end

  test "body_patches apply all-or-nothing" do
    post = Post.create!(title: "Multi", body: "<p>one two</p>")
    result = UpdatePostTool.new.call(id_or_slug: post.slug, body_patches: [ { "old" => "one", "new" => "1" }, { "old" => "MISSING", "new" => "x" } ])

    assert_includes result[:error], "Patch 1"
    assert_includes post.reload.body.to_s, "one"
    assert_not_includes post.reload.body.to_s, "1"
  end

  test "body_patches insert backslash sequences literally" do
    post = Post.create!(title: "Snippets", body: "<p>REPLACE_ME</p>")
    snippet = %q(puts "line\\n" # and \' plus \0 and \1)

    result = UpdatePostTool.new.call(id_or_slug: post.slug, body_patches: [ { "old" => "REPLACE_ME", "new" => snippet } ])

    assert_nil result[:error]
    assert_includes post.reload.body.to_s, snippet
  end

  test "body and body_patches are mutually exclusive" do
    result = UpdatePostTool.new.call(id_or_slug: "a-draft-post", body: "<p>x</p>", body_patches: [ { "old" => "a", "new" => "b" } ])
    assert_includes result[:error], "mutually exclusive"
  end

  test "tags replace the entire set" do
    post = posts(:published)
    assert_equal [ "chronicles" ], post.tags.map(&:name)

    UpdatePostTool.new.call(id_or_slug: post.slug, tags: [ "ai" ])
    assert_equal [ "ai" ], post.reload.tags.map(&:name)
  end

  test "changing a published post's slug warns about the 404" do
    result = UpdatePostTool.new.call(id_or_slug: "a-published-post", slug: "renamed")

    assert_equal "renamed", result[:slug]
    assert_includes result[:warning], "404"
  end

  test "changing a draft's slug carries no warning" do
    result = UpdatePostTool.new.call(id_or_slug: "a-draft-post", slug: "renamed-draft")

    assert_equal "renamed-draft", result[:slug]
    assert_nil result[:warning]
  end
end
