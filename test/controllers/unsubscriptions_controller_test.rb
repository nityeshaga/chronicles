require "test_helper"

class UnsubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "the footer GET only asks — a scanner following the link removes nobody" do
    token = subscribers(:reader).signed_id(purpose: :unsubscribe)

    assert_no_difference -> { Subscriber.count } do
      get unsubscribe_url(token: token, trailing_slash: true)
    end
    assert_response :success
    assert_match "Unsubscribe from the newsletter?", response.body
  end

  test "the confirmation button's POST removes the subscriber" do
    token = subscribers(:reader).signed_id(purpose: :unsubscribe)

    assert_difference -> { Subscriber.count }, -1 do
      post unsubscribe_url(token: token, trailing_slash: true)
    end
    assert_response :success
    assert_match "unsubscribed", response.body
  end

  # Gmail's one-click POST carries no session and no CSRF token; the test env
  # switches forgery protection off, so force it on to prove the skip holds.
  test "one-click POST works with forgery protection enabled" do
    token = subscribers(:reader).signed_id(purpose: :unsubscribe)

    with_forgery_protection do
      assert_difference -> { Subscriber.count }, -1 do
        post unsubscribe_url(token: token, trailing_slash: true)
      end
    end
    assert_response :success
  end

  test "a spent token is idempotent — still lands on the goodbye" do
    token = subscribers(:reader).signed_id(purpose: :unsubscribe)
    subscribers(:reader).destroy

    assert_no_difference -> { Subscriber.count } do
      get unsubscribe_url(token: token, trailing_slash: true)
    end
    assert_response :success
    assert_match "unsubscribed", response.body
  end

  test "a garbage token is refused without error" do
    assert_no_difference -> { Subscriber.count } do
      get unsubscribe_url(token: "not-a-real-token", trailing_slash: true)
    end
    assert_response :success
  end

  private
    def with_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
end
