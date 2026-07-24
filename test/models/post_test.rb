require "test_helper"

class PostTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "generates a slug from the title when blank" do
    post = Post.create!(title: "Hello There World")
    assert_equal "hello-there-world", post.slug
  end

  test "keeps an explicit slug" do
    post = Post.create!(title: "Hello", slug: "custom-slug")
    assert_equal "custom-slug", post.slug
  end

  test "slug uniqueness is enforced" do
    Post.create!(title: "One", slug: "dupe")
    assert_raises(ActiveRecord::RecordInvalid) { Post.create!(title: "Two", slug: "dupe") }
  end

  test "defaults to draft" do
    assert Post.new.draft?
  end

  test "stamps published_at when first published" do
    post = Post.create!(title: "Later", status: :draft)
    assert_nil post.published_at
    post.published!
    assert_not_nil post.published_at
  end

  test "published scope excludes drafts" do
    assert_includes Post.published, posts(:published)
    assert_not_includes Post.published, posts(:draft)
  end

  test "to_param returns the slug" do
    assert_equal posts(:published).slug, posts(:published).to_param
  end

  test "Page is a Post via STI" do
    assert_kind_of Page, posts(:about)
    assert_equal "Page", posts(:about).type
  end

  test "articles carry article view seams; pages carry website ones" do
    post = posts(:published)
    assert_equal "article", post.og_type
    assert_equal "post-template", post.body_class
    assert post.article_meta?

    page = posts(:about)
    assert_equal "website", page.og_type
    assert_equal "page-template", page.body_class
    assert_not page.article_meta?
  end

  test "publish now flips a draft live and stamps a time" do
    post = posts(:draft)
    post.publish
    assert post.reload.published?
    assert_not_nil post.published_at
  end

  test "publish with a future time schedules instead of publishing" do
    post = posts(:draft)
    post.publish(at: 1.day.from_now)
    assert post.reload.draft?
    assert post.scheduled?
    assert post.published_at.future?
  end

  test "publish_if_due only publishes a draft still stamped for that exact schedule" do
    # Floored, as a real job's argument always is (publish_at floors): a raw ns-precision
    # Time.now would lose sub-µs in SQLite and break the identity check on Linux.
    scheduled_for = 1.hour.ago.floor
    due = posts(:draft)
    due.update!(status: :draft, published_at: scheduled_for)
    due.publish_if_due(scheduled_for)
    assert due.reload.published?

    # A stamp that no longer matches the schedule the job carries is a no-op.
    early = Post.create!(title: "Not yet", status: :draft, published_at: 1.day.from_now)
    early.publish_if_due(2.days.from_now)
    assert early.reload.draft?
  end

  test "the scheduled job publishes when it fires on its original schedule" do
    post = posts(:draft)
    # ns-precision stamp (what Time.now yields on Linux) would survive SQLite's
    # µs truncation only if publish_at floors it — this guards that on any clock.
    post.publish(at: 1.hour.from_now.change(nsec: 123_456_789))
    perform_enqueued_jobs
    assert post.reload.published?
  end

  # The republish scenario the schedule guard exists for: schedule Fri, publish now
  # Wed, unpublish Thu — Friday's still-queued job must not resurrect the post the
  # author explicitly unpublished, because published_at no longer matches its schedule.
  test "a stale scheduled job cannot republish a post unpublished after going live early" do
    post = posts(:draft)
    friday = 2.days.from_now.floor # what the enqueued job actually carries (publish_at floors)
    post.publish(at: friday)
    assert post.scheduled?

    post.publish_now
    post.unpublish
    assert post.reload.draft?

    Post::PublishJob.new.perform(post, friday)
    assert post.reload.draft?
  end

  test "unpublish clears a pending schedule" do
    post = posts(:draft)
    post.publish(at: 1.day.from_now)
    post.unpublish
    assert post.reload.draft?
    assert_nil post.published_at
  end

  # --- Feature image seam: the URL column is the source of truth; a native upload
  #     resolves through the same method so callers never branch on how it arrived. ---
  test "feature_image_url returns the URL column when set" do
    assert_equal "/content/images/2022/09/dhh-race-1.jpeg", posts(:published).feature_image_url
  end

  test "feature_image_url falls back to an uploaded attachment when the column is blank" do
    post = posts(:draft)
    assert_nil post.feature_image
    post.uploaded_feature_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/feature.png")),
      filename: "feature.png", content_type: "image/png"
    )
    assert_match %r{/rails/active_storage/blobs/.+/feature\.png}, post.feature_image_url
  end

  # --- Time zone: the site runs on Asia/Kolkata (Ghost parity). Active Record stores
  #     UTC; published_at is read back and rendered in the author's wall clock. ---
  test "the application runs on Asia/Kolkata" do
    assert_equal "Asia/Kolkata", Time.zone.name
  end

  test "a post published late UTC renders the next IST day" do
    post = posts(:draft)
    # 19:30 UTC on 2 Jan is 01:00 IST on 3 Jan (+5:30). The public feed strftimes
    # published_at directly, so the stored UTC must read back in IST.
    post.update!(status: :published, published_at: Time.utc(2025, 1, 2, 19, 30))
    assert_equal "3 Jan 2025", post.reload.published_at.strftime("%-d %b %Y")
  end

  test "scheduling parses a typed datetime as IST, not UTC" do
    post = posts(:draft)
    post.publish(at: "2030-06-01T10:00")
    assert post.scheduled?
    # 10:00 IST is 04:30 UTC — proves the -5:30 offset was applied on parse.
    assert_equal Time.utc(2030, 6, 1, 4, 30), post.reload.published_at.utc
  end

  test "newlines are squished out of the title and excerpt" do
    post = Post.create!(title: "A headline\nsplit  across lines", excerpt: "One\nstandfirst\n")
    assert_equal "A headline split across lines", post.title
    assert_equal "One standfirst", post.excerpt
  end
end
