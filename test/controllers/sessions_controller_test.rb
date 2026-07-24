require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "sign in page is public" do
    get new_session_url
    assert_response :success
  end

  test "signs in with correct credentials" do
    sign_in_as users(:nityesh)
    assert_redirected_to writing_root_url
  end

  test "rejects wrong credentials" do
    post session_url, params: { email_address: users(:nityesh).email_address, password: "wrong" }
    assert_redirected_to new_session_url
  end

  test "sign out clears the session" do
    sign_in_as users(:nityesh)
    delete session_url
    assert_redirected_to root_url
  end

  # The test env's cache is :null_store, whose increment never counts, so rate_limit
  # can't trip on its own. rate_limit captures ActionController::Base.cache_store at
  # class-load, so give that same object a real counter for the length of this test.
  test "throttles repeated login attempts" do
    store = ActionController::Base.cache_store
    counts = Hash.new(0)
    store.define_singleton_method(:increment) { |key, amount = 1, options = nil| counts[key] += amount }
    begin
      11.times do
        post session_url, params: { email_address: users(:nityesh).email_address, password: "wrong" }
      end
    ensure
      store.singleton_class.remove_method(:increment)
    end
    assert_redirected_to new_session_url
    assert_equal "Try again later.", flash[:alert]
  end
end
