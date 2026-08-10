require "test_helper"

class UnsubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "a valid token removes the subscriber and confirms" do
    token = subscribers(:reader).signed_id(purpose: :unsubscribe)

    assert_difference -> { Subscriber.count }, -1 do
      get unsubscribe_url(token: token, trailing_slash: true)
    end
    assert_response :success
    assert_match "unsubscribed", response.body
  end

  test "one-click POST also removes the subscriber" do
    token = subscribers(:reader).signed_id(purpose: :unsubscribe)

    assert_difference -> { Subscriber.count }, -1 do
      post unsubscribe_url(token: token, trailing_slash: true)
    end
    assert_response :success
  end

  test "a spent token is idempotent — still lands on the confirmation" do
    token = subscribers(:reader).signed_id(purpose: :unsubscribe)
    subscribers(:reader).destroy

    assert_no_difference -> { Subscriber.count } do
      get unsubscribe_url(token: token, trailing_slash: true)
    end
    assert_response :success
  end

  test "a garbage token is refused without error" do
    assert_no_difference -> { Subscriber.count } do
      get unsubscribe_url(token: "not-a-real-token", trailing_slash: true)
    end
    assert_response :success
  end
end
