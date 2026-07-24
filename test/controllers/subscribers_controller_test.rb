require "test_helper"

class SubscribersControllerTest < ActionDispatch::IntegrationTest
  test "a valid signup is stored and confirmed via turbo stream" do
    assert_difference -> { Subscriber.count }, 1 do
      post subscribers_url, params: { email: "Fresh@Example.com " }, as: :turbo_stream
    end
    assert_response :success
    assert_equal "fresh@example.com", Subscriber.last.email
    assert_match "First class", response.body
  end

  test "a duplicate signup is idempotent and returns the same confirmation" do
    subscribers(:reader) # ensure the row exists
    assert_no_difference -> { Subscriber.count } do
      post subscribers_url, params: { email: "READER@example.com" }, as: :turbo_stream
    end
    assert_response :success
    assert_match "First class", response.body
  end

  test "an invalid email re-renders the form with an error via turbo stream" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_url, params: { email: "nope" }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_match "subscribe_form", response.body
    assert_select "form.sub-form"
  end

  test "html fallback redirects to the subscribe anchor with a flash on success" do
    assert_difference -> { Subscriber.count }, 1 do
      post subscribers_url, params: { email: "html@example.com" }
    end
    assert_redirected_to root_url(anchor: "subscribe")
    assert_equal "First class. You're on the list.", flash[:notice]
  end

  test "html fallback redirects with an alert on an invalid email" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_url, params: { email: "nope" }
    end
    assert_redirected_to root_url(anchor: "subscribe")
    assert flash[:alert].present?
  end
end
