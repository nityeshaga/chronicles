require "test_helper"

class McpTransportTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:nityesh)
    @token = @user.api_tokens.create!(name: "Claude Code").plain_token
  end

  test "initialize handshake with a valid bearer token opens a session" do
    initialize_mcp(@token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "2.0", body["jsonrpc"]
    assert_equal "nityesh-com", body.dig("result", "serverInfo", "name")
    assert response.headers["MCP-Session-Id"].present?
    assert_equal @user.id, McpSession.find(response.headers["MCP-Session-Id"]).user_id
  end

  test "a valid session can list the registered tools" do
    initialize_mcp(@token)
    session_id = response.headers["MCP-Session-Id"]

    post_mcp({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }, token: @token, session_id: session_id)

    assert_response :success
    names = JSON.parse(response.body).dig("result", "tools").map { |t| t["name"] }
    expected = %w[ list_posts get_post list_tags create_post update_post publish_post unpublish_post delete_post update_tag upload_image create_embed create_html_page update_html_page create_html_card update_html_card ]
    assert_equal expected.sort, names.sort
  end

  test "a missing token is rejected" do
    post "/mcp", params: initialize_payload.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "a bad token is rejected" do
    initialize_mcp("not-a-real-token")
    assert_response :unauthorized
  end

  test "an expired token is rejected" do
    expired = @user.api_tokens.create!(name: "expired", expires_at: 1.hour.ago).plain_token
    initialize_mcp(expired)
    assert_response :unauthorized
  end

  test "another user cannot ride a session opened by someone else" do
    initialize_mcp(@token)
    session_id = response.headers["MCP-Session-Id"]

    other = User.create!(name: "Other", email_address: "other@example.com", password: "secret123")
    other_token = other.api_tokens.create!(name: "theirs").plain_token

    post_mcp({ jsonrpc: "2.0", id: 3, method: "tools/list", params: {} }, token: other_token, session_id: session_id)
    assert_response :forbidden
  end

  test "touching the endpoint stamps the token's last_used_at" do
    token = @user.api_tokens.create!(name: "usage")
    assert_nil token.last_used_at

    initialize_mcp(token.plain_token)
    assert response.successful?
    assert token.reload.last_used_at.present?
  end

  private
    def initialize_payload
      {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2025-11-25",
          capabilities: {},
          clientInfo: { name: "test-client", version: "1.0" }
        }
      }
    end

    def initialize_mcp(token)
      post_mcp(initialize_payload, token: token)
    end

    def post_mcp(payload, token:, session_id: nil)
      headers = { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
      headers["MCP-Session-Id"] = session_id if session_id
      post "/mcp", params: payload.to_json, headers: headers
    end
end
