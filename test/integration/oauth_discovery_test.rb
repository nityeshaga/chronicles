require "test_helper"

class OauthDiscoveryTest < ActionDispatch::IntegrationTest
  test "authorization server metadata advertises the endpoints and PKCE" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal root_url, body["issuer"]
    assert_equal oauth_authorization_url, body["authorization_endpoint"]
    assert_equal oauth_token_url, body["token_endpoint"]
    assert_equal oauth_register_url, body["registration_endpoint"]
    assert_equal [ "code" ], body["response_types_supported"]
    assert_equal [ "authorization_code" ], body["grant_types_supported"]
    assert_equal [ "S256" ], body["code_challenge_methods_supported"]
    assert_equal true, body["client_id_metadata_document_supported"]
  end

  test "the metadata is reachable with a resource path suffix" do
    get "/.well-known/oauth-authorization-server/mcp"

    assert_response :success
    assert_equal oauth_register_url, JSON.parse(response.body)["registration_endpoint"]
  end

  test "protected resource metadata points at this server and names the resource" do
    get "/.well-known/oauth-protected-resource/mcp"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "#{request.base_url}/mcp", body["resource"]
    assert_equal [ root_url.chomp("/") ], body["authorization_servers"]
    assert_equal [ "header" ], body["bearer_methods_supported"]
    assert_equal Setting.current.production_host, body["resource_name"]
  end
end
