require "test_helper"

class OauthRegistrationTest < ActionDispatch::IntegrationTest
  test "a public client registering with localhost and https redirect URIs succeeds" do
    register(
      client_name: "Claude Code",
      redirect_uris: [ "http://localhost:41234/callback", "https://claude.ai/api/mcp/auth_callback" ],
      token_endpoint_auth_method: "none"
    )

    assert_response :created
    body = JSON.parse(response.body)
    assert body["client_id"].present?
    assert_equal "Claude Code", body["client_name"]
    assert_equal "none", body["token_endpoint_auth_method"]
    assert_nil body["client_secret"]

    application = Doorkeeper::Application.find_by(uid: body["client_id"])
    assert_not application.confidential?
    assert_equal "dcr", application.registration_type
  end

  test "a confidential client is issued a secret" do
    register(client_name: "Web App", redirect_uris: [ "https://example.com/cb" ])

    assert_response :created
    body = JSON.parse(response.body)
    assert body["client_secret"].present?
  end

  test "a non-localhost http redirect URI is rejected" do
    register(redirect_uris: [ "http://evil.example.com/cb" ])

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", JSON.parse(response.body)["error"]
  end

  test "an unsupported grant type is rejected" do
    register(redirect_uris: [ "https://example.com/cb" ], grant_types: [ "implicit" ])

    assert_response :bad_request
    assert_equal "invalid_client_metadata", JSON.parse(response.body)["error"]
  end

  # test.rb disables forgery protection globally, which is how the missing
  # skip_forgery_protection shipped past a green suite; re-enable it here so
  # this endpoint is proven open to real JSON clients that carry no CSRF token.
  test "registration works with forgery protection enabled" do
    ActionController::Base.allow_forgery_protection = true
    register(client_name: "CSRF Check", redirect_uris: [ "https://example.com/cb" ])
    assert_response :created
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "a missing redirect_uris is rejected" do
    register(client_name: "No Redirect")

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", JSON.parse(response.body)["error"]
  end

  private
    def register(payload)
      post "/oauth/register", params: payload.to_json,
        headers: { "Content-Type" => "application/json" }
    end
end
