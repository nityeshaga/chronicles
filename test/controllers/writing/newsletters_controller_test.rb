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

  test "a draft is refused" do
    sign_in_as users(:nityesh)
    assert_no_enqueued_jobs do
      post writing_post_newsletter_url(posts(:draft))
    end
    assert_redirected_to edit_writing_post_url(posts(:draft))
  end
end
