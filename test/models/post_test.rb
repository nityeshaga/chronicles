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

  # Public posts live at the site root, so a name the router already answers for would
  # save fine and then be unreachable at its own address.
  test "a slug the router already owns is refused" do
    post = Post.new(title: "Writing", slug: "writing")
    assert_not post.valid?
    assert_includes post.errors[:slug], "is a name the site already uses"
  end

  test "an invented slug steps past names that are taken or reserved" do
    Post.create!(title: "Notes")
    assert_equal "notes-2", Post.create!(title: "Notes").slug
    assert_equal "writing-2", Post.create!(title: "Writing").slug
  end

  # The editor's save. Asked to derive, the URL follows the title instead of freezing at
  # whatever the first two seconds of typing it produced.
  test "the editor's save re-derives the URL from the title when asked to" do
    post = Post.create!(title: "Why I Mov")
    assert_equal "why-i-mov", post.slug

    post.save_keeping_url({ title: "Why I Moved My Blog" }, derive_slug: true)
    assert_equal "why-i-moved-my-blog", post.reload.slug
  end

  # A keystroke is never refused over a URL: the name that isn't free is dropped, the
  # prose it arrived with is not.
  test "the editor's save keeps the slug it had when the one asked for isn't free" do
    Post.create!(title: "One", slug: "spoken-for")
    post = Post.create!(title: "Two", slug: "mine")

    assert post.save_keeping_url({ slug: "spoken-for", title: "Two, Revised" })
    assert_equal "mine", post.reload.slug
    assert_equal "Two, Revised", post.title

    assert post.save_keeping_url({ slug: "writing" })
    assert_equal "mine", post.reload.slug
  end

  # An emptied field is a name the post can't have, not a request to invent a new one —
  # reading the two as one thing is how a cleared field once moved a published URL.
  test "the editor's save keeps the slug it had when the field arrives empty" do
    post = Post.create!(title: "Live One", slug: "live-one", status: :published)

    assert post.save_keeping_url({ slug: "", excerpt: "still edited" })
    assert_equal "live-one", post.reload.slug
    assert_equal "still edited", post.excerpt
  end

  # An old post holding a name the router has since claimed must still be publishable:
  # what is reserved changes with routes.rb, and only a slug that is moving is asked.
  test "a reserved name is only refused of a slug that is moving" do
    post = Post.create!(title: "Legacy", slug: "legacy")
    post.update_column(:slug, "writing")

    assert post.reload.publish
    assert post.published?
  end

  # Every other caller can read an error, so every other caller still gets one.
  test "a plain save still refuses a slug that is taken" do
    Post.create!(title: "One", slug: "spoken-for")
    post = Post.create!(title: "Two", slug: "mine")

    assert_not post.update(slug: "spoken-for")
    assert_equal "mine", post.reload.slug
  end

  # Once a post is addressed, someone can be holding the link — the editor stops
  # re-deriving the URL from the title and only a hand edit moves it.
  test "addressed covers a live post and one committed to going live" do
    assert posts(:published).addressed?
    assert posts(:scheduled).addressed?
    assert_not posts(:draft).addressed?
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

  # A time already gone used to mean "publish now", which turns a typo about yesterday
  # into a live post nobody asked for. It is refused instead, and the reason comes back
  # in the words the editor prints.
  test "a publish time that has already passed is refused" do
    post = posts(:draft)

    assert_not post.publish(at: 1.hour.ago)
    assert_equal [ "That time has already passed — pick a later one, or clear it to publish now." ],
      post.errors.full_messages
    assert post.reload.draft?
    assert_nil post.published_at
  end

  # The second door onto the same rule: #publish answers false, but publish_at is public
  # and a past time there would enqueue a job whose wait_until has already elapsed — the
  # queue would fire it at once and "schedule" would silently mean "publish now".
  test "publish_at raises rather than schedule a time that has already passed" do
    assert_raises(ArgumentError) { posts(:draft).publish_at(1.hour.ago) }
    assert_no_enqueued_jobs only: Post::PublishJob
    assert posts(:draft).reload.draft?
    assert_nil posts(:draft).published_at
  end

  # No time at all still means now — the scheduled job calls back through exactly this
  # door once its own time is in the past.
  test "publish with no time given still publishes now" do
    post = posts(:draft)
    assert post.publish
    assert post.reload.published?
  end

  # The placeholder title exists so body-first writing can autosave; it is not a title
  # anyone chose, and shipping it would put nityesh.com/untitled/ on the site for good.
  test "an untitled draft refuses to publish or schedule, and says why" do
    post = Post.create!(body: "<p>a body, no title yet</p>")
    assert post.untitled?

    assert_not post.publish
    assert_not post.publish(at: 1.day.from_now)
    assert_equal [ "Title is still the placeholder — name the post before it goes live" ],
      post.errors.full_messages
    assert post.reload.draft?
    assert_nil post.published_at
  end

  test "a titled draft is not untitled" do
    assert_not posts(:draft).untitled?
    assert posts(:draft).publish
  end

  # The refusal is a validation, not a guard inside #publish, so it holds for the verbs
  # underneath too — the only reason it can be trusted on a path nobody is watching.
  test "the publish verbs raise rather than write an untitled post live" do
    post = Post.create!(body: "<p>no title</p>")

    assert_raises(ActiveRecord::RecordInvalid) { post.publish_now }
    assert_raises(ActiveRecord::RecordInvalid) { post.publish_at(1.day.from_now) }
    assert post.reload.draft?
  end

  # The scenario the validation exists for: schedule a titled post, then clear the title.
  # A draft would quietly re-fill the placeholder and the job would put /untitled/ live
  # hours later, with nobody watching. A post with a schedule waiting to fire is already
  # on its way to the public, so the title cannot be taken off it.
  test "the title of a scheduled post cannot be cleared" do
    post = posts(:draft)
    at = 1.hour.from_now.floor
    assert post.publish(at: at)

    assert_not post.update(title: "")
    assert_equal "A Draft Post", post.reload.title
  end

  # And if a row gets past that anyway — a direct write, a record older than the rule —
  # the job still refuses it, because the refusal lives at the boundary rather than in
  # the verb the job happens to call.
  test "the scheduled job will not publish a post that is untitled by the time it fires" do
    post = posts(:draft)
    at = 1.hour.from_now.floor
    assert post.publish(at: at)
    post.update_column(:title, Post::PLACEHOLDER_TITLE)

    post.reload.publish_if_due(at)

    assert post.reload.draft?
    assert_equal at, post.published_at
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
