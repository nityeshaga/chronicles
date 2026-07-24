require "test_helper"

class Writing::ConnectsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get writing_connect_url
    assert_redirected_to new_session_url
  end

  test "renders every connection section" do
    sign_in_as users(:nityesh)
    get writing_connect_url
    assert_response :success
    assert_select "h2", text: "Claude Code"
    assert_select "h2", text: /Claude\.ai/
    assert_select "h2", text: "API tokens"
    assert_select "h2", text: "Connected apps"
  end

  test "shows the live-host mcp command and connector URL" do
    sign_in_as users(:nityesh)
    get writing_connect_url
    assert_select "pre", text: %r{claude mcp add --transport http nityesh-com http://www\.example\.com/mcp}
    assert_select "code", text: "http://www.example.com/mcp"
  end

  test "lists the author's tokens" do
    sign_in_as users(:nityesh)
    users(:nityesh).api_tokens.create!(name: "Claude Code")
    get writing_connect_url
    assert_select ".dash-row__title", text: "Claude Code"
  end

  test "shows the flash-once token after a create redirect" do
    sign_in_as users(:nityesh)
    post writing_api_tokens_url, params: { api_token: { name: "Fresh" } }
    follow_redirect!
    assert_select ".connect-token code"
  end

  test "empty state when no apps are connected" do
    sign_in_as users(:nityesh)
    get writing_connect_url
    assert_select ".dash-blank", text: /claude\.ai connections will appear here/
  end
end
