require "test_helper"

class Writing::ApiTokensControllerTest < ActionDispatch::IntegrationTest
  test "create requires authentication" do
    post writing_api_tokens_url, params: { api_token: { name: "x" } }
    assert_redirected_to new_session_url
  end

  test "creating a token redirects to Connect and shows the plaintext exactly once" do
    sign_in_as users(:nityesh)
    assert_difference -> { ApiToken.count }, 1 do
      post writing_api_tokens_url, params: { api_token: { name: "Luo Ji" } }
    end
    assert_redirected_to writing_connect_url

    token = ApiToken.order(:created_at).last
    plain = flash[:new_token]
    assert_equal token.token_digest, ApiToken.digest_token(plain)

    follow_redirect!
    assert_select "code", text: plain

    # A second visit no longer reveals it — flash is gone.
    get writing_connect_url
    assert_select "code", text: plain, count: 0
  end

  test "creating a token without a name redirects back with an alert" do
    sign_in_as users(:nityesh)
    assert_no_difference -> { ApiToken.count } do
      post writing_api_tokens_url, params: { api_token: { name: "" } }
    end
    assert_redirected_to writing_connect_url
    assert flash[:alert].present?
  end

  test "revoking a token destroys it" do
    sign_in_as users(:nityesh)
    token = users(:nityesh).api_tokens.create!(name: "Claude Code")
    assert_difference -> { ApiToken.count }, -1 do
      delete writing_api_token_url(token)
    end
    assert_redirected_to writing_connect_url
  end

  test "cannot revoke another user's token" do
    other = User.create!(name: "Other", email_address: "other@example.com", password: "secret123")
    token = other.api_tokens.create!(name: "theirs")
    sign_in_as users(:nityesh)
    assert_no_difference -> { ApiToken.count } do
      delete writing_api_token_url(token)
    end
    assert_response :not_found
  end
end
