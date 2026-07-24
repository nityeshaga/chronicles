require "test_helper"

class OauthFlowTest < ActionDispatch::IntegrationTest
  REDIRECT_URI = "https://claude.ai/api/mcp/auth_callback".freeze

  setup do
    @user = users(:nityesh)
    @application = Doorkeeper::Application.create!(
      name: "Claude", redirect_uri: REDIRECT_URI, confidential: false,
      secret: nil, registration_type: "dcr"
    )
    @verifier = SecureRandom.urlsafe_base64(64)
    @challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false)
  end

  test "a logged-out authorize bounces to login, then round-trips to consent and issues a usable token" do
    get authorize_url

    assert_redirected_to new_session_url
    assert_equal authorize_path, session[:return_to_after_authenticating]

    post session_url, params: { email_address: @user.email_address, password: "secret123" }
    assert_redirected_to authorize_path

    follow_redirect!
    assert_response :success
    assert_select "input[name=code_challenge][value=?]", @challenge

    post oauth_authorization_url, params: authorize_params
    assert_response :redirect
    code = Rack::Utils.parse_query(URI(response.location).query)["code"]
    assert code.present?

    post oauth_token_url, params: {
      grant_type: "authorization_code", code: code, redirect_uri: REDIRECT_URI,
      client_id: @application.uid, code_verifier: @verifier
    }
    assert_response :success
    access_token = JSON.parse(response.body)["access_token"]
    assert access_token.present?

    initialize_mcp(access_token)
    assert_response :success
    assert_equal "nityesh-com", JSON.parse(response.body).dig("result", "serverInfo", "name")
    assert_equal @user.id, McpSession.find(response.headers["MCP-Session-Id"]).user_id
  end

  test "the token exchange fails without the PKCE verifier" do
    sign_in
    post oauth_authorization_url, params: authorize_params
    code = Rack::Utils.parse_query(URI(response.location).query)["code"]

    post oauth_token_url, params: {
      grant_type: "authorization_code", code: code, redirect_uri: REDIRECT_URI,
      client_id: @application.uid
    }
    assert_response :bad_request
  end

  private
    def authorize_params
      {
        client_id: @application.uid, redirect_uri: REDIRECT_URI, response_type: "code",
        scope: "public", code_challenge: @challenge, code_challenge_method: "S256"
      }
    end

    def authorize_path
      "#{oauth_authorization_path}?#{authorize_params.to_query}"
    end

    def authorize_url
      "#{oauth_authorization_url}?#{authorize_params.to_query}"
    end

    def sign_in
      post session_url, params: { email_address: @user.email_address, password: "secret123" }
    end

    def initialize_mcp(token)
      payload = {
        jsonrpc: "2.0", id: 1, method: "initialize",
        params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "t", version: "1" } }
      }
      post "/mcp", params: payload.to_json,
        headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
    end
end
