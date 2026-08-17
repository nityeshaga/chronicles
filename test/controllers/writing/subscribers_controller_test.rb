require "test_helper"

class Writing::SubscribersControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get writing_subscribers_url
    assert_redirected_to new_session_url
  end

  # The empty state describes the populated view, so "what will this look like" is answered
  # before the first subscriber arrives.
  test "the empty state describes the list that will appear" do
    Subscriber.delete_all
    sign_in_as users(:nityesh)
    get writing_subscribers_url
    # The load-bearing half is the description of the list, not the whole sentence.
    assert_select ".dash-blank p", text: /email and the date they joined, newest first/
  end

  test "index lists subscribers newest-first when signed in" do
    sign_in_as users(:nityesh)
    get writing_subscribers_url
    assert_response :success
    assert_select ".dash-row__title", text: "reader@example.com"
    # reader is 2 days old, early is 5 days old — newest must come first.
    assert_operator response.body.index("reader@example.com"), :<,
      response.body.index("early@example.com")
  end
end
