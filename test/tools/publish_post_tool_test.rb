require "test_helper"

class PublishPostToolTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, PublishPostTool.new.call(id_or_slug: "a-draft-post")
  end

  test "publishes immediately when no at is given" do
    post = posts(:draft)
    result = PublishPostTool.new.call(id_or_slug: post.slug)

    assert_equal "published", result[:status]
    assert post.reload.published?
    assert_equal "https://#{Setting.current.production_host}/a-draft-post/", result[:url]
    assert_not_nil result[:published_at]
  end

  test "schedules with a floored timestamp carried into the enqueued job" do
    post = posts(:draft)
    at = "2099-01-01T10:15:30.123456Z"

    result = PublishPostTool.new.call(id_or_slug: post.slug, at: at)

    assert_equal "scheduled", result[:status]
    assert_nil result[:url]

    floored = Time.iso8601(at).floor
    assert_equal floored, post.reload.published_at
    assert_equal floored, Time.iso8601(result[:published_at])
    assert_enqueued_with(job: Post::PublishJob, args: [ post, floored ])
  end

  test "rescheduling re-stamps the time and the stale job no-ops" do
    post = posts(:draft)
    t1 = 2.days.from_now.change(usec: 0)
    t2 = 4.days.from_now.change(usec: 0)

    PublishPostTool.new.call(id_or_slug: post.slug, at: t1.iso8601)
    PublishPostTool.new.call(id_or_slug: post.slug, at: t2.iso8601)

    assert_equal t2, post.reload.published_at

    # The first job carries t1; its identity check no longer matches, so it no-ops.
    post.publish_if_due(t1)
    assert post.reload.draft?

    # The live schedule (t2) still fires.
    post.publish_if_due(t2)
    assert post.reload.published?
  end

  test "rejects an at in the past" do
    result = PublishPostTool.new.call(id_or_slug: "a-draft-post", at: 1.day.ago.iso8601)
    assert_includes result[:error], "past"
    assert posts(:draft).reload.draft?
  end

  test "rejects an unparseable at with an example format" do
    result = PublishPostTool.new.call(id_or_slug: "a-draft-post", at: "not-a-time")
    assert_includes result[:error], "ISO8601"
  end

  test "returns a recovery error when not found" do
    assert_equal ToolErrors::POST_NOT_FOUND, PublishPostTool.new.call(id_or_slug: "nope")
  end

  # The UI refuses an untitled post; the API has to refuse it for the same reason, or the
  # guard is one client away from being decorative. The sentence is the model's, not this
  # tool's, so a new rule reaches the agent without anyone editing the tool.
  test "refuses an untitled post, now or scheduled, in the model's own words" do
    post = Post.create!(body: "<p>drafted by an agent, not yet named</p>")
    reason = "Title is still the placeholder — name the post before it goes live"

    assert_equal reason, PublishPostTool.new.call(id_or_slug: post.slug)[:error]
    assert_equal reason, PublishPostTool.new.call(id_or_slug: post.slug, at: 1.day.from_now.iso8601)[:error]
    assert post.reload.draft?
    assert_nil post.published_at
  end

  # HTML pages ride the same publishing verbs as everything else; the tools need no
  # branch for them, which is the whole argument for the kind being one STI subclass.
  test "publishes and unpublishes an html page like any other record" do
    page = HtmlPage.create!(title: "Round Trip", raw_html: "<html><head><title>T</title></head><body>x</body></html>")

    published = PublishPostTool.new.call(id_or_slug: page.slug)
    assert_equal "published", published[:status]
    assert_equal "https://#{Setting.current.production_host}/round-trip/", published[:url]
    assert page.reload.published?

    unpublished = UnpublishPostTool.new.call(id_or_slug: page.slug)
    assert_equal "draft", unpublished[:status]
    assert page.reload.draft?
  end
end
