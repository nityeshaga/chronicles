# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  # Doorkeeper's controllers don't inherit from ApplicationController, so the
  # Authentication concern's before_action never runs here — resume this app's
  # session by hand (signed cookie -> Session id -> Current.user) and, if nobody
  # is signed in, stash the authorize URL so login can round-trip back to it.
  resource_owner_authenticator do
    Current.session ||= Session.find_by(id: cookies.signed[:session_token])

    Current.user || begin
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to new_session_path
    end
  end

  authorization_code_expires_in 10.minutes
  access_token_expires_in 1.year

  default_scopes :public
  optional_scopes :claudeai

  grant_flows %w[ authorization_code ]

  # PKCE, S256 only — required by the MCP spec and by claude.ai's public client.
  force_pkce
  pkce_code_challenge_methods %w[ S256 ]

  # Native clients (Claude Code, MCP Inspector) redirect to loopback; everything
  # else must be HTTPS.
  force_ssl_in_redirect_uri ->(uri) { !uri.host.in?(%w[ localhost 127.0.0.1 ]) }
end
