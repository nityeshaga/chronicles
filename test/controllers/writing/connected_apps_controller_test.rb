require "test_helper"

class Writing::ConnectedAppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:nityesh)
    @app = Doorkeeper::Application.create!(
      name: "Claude", redirect_uri: "https://claude.ai/api/mcp/auth_callback",
      confidential: false, secret: nil, registration_type: "dcr"
    )
    @token = Doorkeeper::AccessToken.create!(
      application: @app, resource_owner_id: @user.id, scopes: "public"
    )
  end

  test "destroy requires authentication" do
    delete writing_connected_app_url(@app.id)
    assert_redirected_to new_session_url
  end

  test "a connected app is listed, then disappears once revoked" do
    sign_in_as @user
    get writing_connect_url
    assert_select ".dash-row__title", text: "Claude"

    delete writing_connected_app_url(@app.id)
    assert_redirected_to writing_connect_url
    assert @token.reload.revoked?

    follow_redirect!
    assert_select ".dash-row__title", text: "Claude", count: 0
    assert_select ".dash-blank", text: /claude\.ai connections will appear here/
  end

  test "does not revoke another user's tokens" do
    other = User.create!(name: "Other", email_address: "other@example.com", password: "secret123")
    other_token = Doorkeeper::AccessToken.create!(
      application: @app, resource_owner_id: other.id, scopes: "public"
    )
    sign_in_as @user
    delete writing_connected_app_url(@app.id)
    assert_not other_token.reload.revoked?
  end
end
