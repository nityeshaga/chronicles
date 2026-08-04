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

  # The gate and the patch contract are unit-tested; what only the wire can prove is that
  # an html_patches array of objects survives the transport's schema validation.
  test "create_html_page then update_html_page round-trips a document through the transport" do
    session_id = open_session
    document = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<title>Wire Landing</title>\n<meta name=\"description\" content=\"x\">\n</head>\n<body><h1>Wire Landing</h1></body>\n</html>\n"

    call_tool("create_html_page", { title: "Wire Landing", html: document }, session_id)
    assert_response :success
    create_result = JSON.parse(response.body).dig("result")
    assert_not create_result["isError"]
    assert_includes create_result.dig("content", 0, "text"), "wire-landing"

    call_tool("update_html_page", {
      id_or_slug: "wire-landing",
      html_patches: [ { old: "<h1>Wire Landing</h1>", new: "<h1>Wire Landed</h1>" } ]
    }, session_id)
    assert_response :success
    update_result = JSON.parse(response.body).dig("result")
    assert_not update_result["isError"]

    page = HtmlPage.find_by(slug: "wire-landing")
    assert_includes page.raw_html, "<h1>Wire Landed</h1>"
    assert_equal 1, page.raw_html.scan(/rel="canonical"/).size
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
