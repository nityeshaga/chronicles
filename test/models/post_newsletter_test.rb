require "test_helper"

class PostNewsletterTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  test "delivering a published post stamps it and enqueues the fan-out job" do
    post = posts(:published)
    assert_not post.newsletter_sent?

    assert_enqueued_with(job: Post::NewsletterJob) do
      assert post.deliver_newsletter
    end

    assert post.reload.newsletter_sent?
    assert_equal Subscriber.count, post.newsletter_recipients_count
  end

  test "a draft can't be mailed" do
    post = posts(:draft)
    assert_no_enqueued_jobs do
      assert_not post.deliver_newsletter
    end
    assert_not post.reload.newsletter_sent?
  end

  test "an already-sent post can't be mailed again" do
    post = posts(:published)
    post.deliver_newsletter

    assert_no_enqueued_jobs only: Post::NewsletterJob do
      assert_not post.deliver_newsletter
    end
  end

  # The send is one-shot. An empty list must be a refusal, not a stamped no-op, or a
  # stale tab burns the post's only send on nobody and records "mailed to 0".
  test "a post with no subscribers can't be mailed, and keeps its send" do
    Subscriber.delete_all
    post = posts(:published)

    assert_no_enqueued_jobs do
      assert_not post.deliver_newsletter
    end
    assert_nil post.reload.newsletter_sent_at
  end

  test "the fan-out job mails every subscriber once" do
    assert_enqueued_emails Subscriber.count do
      Post::NewsletterJob.perform_now(posts(:published))
    end
  end
end
