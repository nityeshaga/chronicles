# frozen_string_literal: true

# OAuth 2.0 metadata discovery endpoints.
#
# - Authorization Server Metadata (RFC 8414): /.well-known/oauth-authorization-server
# - Protected Resource Metadata (RFC 9728): /.well-known/oauth-protected-resource[/*path]
class OauthMetadataController < ApplicationController
  allow_unauthenticated_access

  # RFC 8414 — tells clients where to authorize and exchange tokens.
  def show
    render json: {
      issuer: root_url,
      authorization_endpoint: oauth_authorization_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_register_url,
      response_types_supported: [ "code" ],
      grant_types_supported: [ "authorization_code" ],
      token_endpoint_auth_methods_supported: [ "client_secret_post", "client_secret_basic", "none" ],
      revocation_endpoint: oauth_revoke_url,
      code_challenge_methods_supported: [ "S256" ],
      registration_endpoint_auth_methods_supported: [],
      client_id_metadata_document_supported: true
    }
  end

  # RFC 9728 — tells clients which authorization server protects this resource.
  # The resource field must match the identifier the client used to derive the
  # well-known URL, so we build it from the request path suffix.
  def protected_resource
    resource_path = params[:path].present? ? "/#{params[:path]}" : ""

    render json: {
      resource: "#{request.base_url}#{resource_path}",
      authorization_servers: [ root_url.chomp("/") ],
      bearer_methods_supported: [ "header" ],
      scopes_supported: [ "public" ],
      resource_name: Setting.current.production_host
    }
  end
end
