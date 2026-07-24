require "test_helper"

class McpToolsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:nityesh)
    @token = @user.api_tokens.create!(name: "Claude Code").plain_token
  end

  test "list_posts is callable end-to-end through the transport" do
    session_id = open_session

    call_tool("list_posts", { status: "published" }, session_id)

    assert_response :success
    result = JSON.parse(response.body).dig("result")
    assert_not result["isError"]

    text = result.dig("content", 0, "text")
    assert_includes text, "a-published-post"
    assert_includes text, "total_count"
    assert_not_includes text, "body"
  end

  test "create_post then get_post round-trips a draft through the transport" do
    session_id = open_session

    call_tool("create_post", { title: "From The Wire", body: "<p>Hello</p>" }, session_id)
    assert_response :success
    create_result = JSON.parse(response.body).dig("result")
    assert_not create_result["isError"]
    assert_includes create_result.dig("content", 0, "text"), "from-the-wire"

    call_tool("get_post", { id_or_slug: "from-the-wire" }, session_id)
    assert_response :success
    get_text = JSON.parse(response.body).dig("result", "content", 0, "text")
    assert_includes get_text, "From The Wire"
    assert_includes get_text, "draft"
  end

  private
    def open_session
      post_mcp({
        jsonrpc: "2.0", id: 1, method: "initialize",
        params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "1.0" } }
      })
      response.headers["MCP-Session-Id"]
    end

    def call_tool(name, arguments, session_id)
      post_mcp({
        jsonrpc: "2.0", id: 2, method: "tools/call",
        params: { name: name, arguments: arguments }
      }, session_id)
    end

    def post_mcp(payload, session_id = nil)
      headers = { "Content-Type" => "application/json", "Authorization" => "Bearer #{@token}" }
      headers["MCP-Session-Id"] = session_id if session_id
      post "/mcp", params: payload.to_json, headers: headers
    end
end
