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

  test "the fan-out job mails every subscriber once" do
    assert_enqueued_emails Subscriber.count do
      Post::NewsletterJob.perform_now(posts(:published))
    end
  end
end
