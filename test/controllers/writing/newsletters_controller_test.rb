require "test_helper"

class Writing::NewslettersControllerTest < ActionDispatch::IntegrationTest
  test "sending requires authentication" do
    assert_no_enqueued_jobs do
      post writing_post_newsletter_url(posts(:published))
    end
    assert_redirected_to new_session_url
  end

  test "a published post is queued to the list" do
    sign_in_as users(:nityesh)
    assert_enqueued_with(job: Post::NewsletterJob) do
      post writing_post_newsletter_url(posts(:published))
    end
    assert_redirected_to edit_writing_post_url(posts(:published))
    assert posts(:published).reload.newsletter_sent?
  end

  # The view hides the button when the list is empty; this is the same rule at the door,
  # for the stale tab that posts anyway.
  test "a post with no subscribers is refused rather than stamped" do
    Subscriber.delete_all
    sign_in_as users(:nityesh)
    assert_no_enqueued_jobs do
      post writing_post_newsletter_url(posts(:published))
    end
    assert_redirected_to edit_writing_post_url(posts(:published))
    assert_nil posts(:published).reload.newsletter_sent_at

    # And the refusal is readable: with the backdrop up, the popover is the only thing
    # the writer can see, so it goes there rather than behind it.
    follow_redirect!
    assert_select ".publish-popover .publish-note--refused", text: /can’t be sent/
    assert_select "ul.errors", count: 0
  end

  test "a draft is refused" do
    sign_in_as users(:nityesh)
    assert_no_enqueued_jobs do
      post writing_post_newsletter_url(posts(:draft))
    end
    assert_redirected_to edit_writing_post_url(posts(:draft))
  end
end
