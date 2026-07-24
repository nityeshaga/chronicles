# frozen_string_literal: true

# Dynamic Client Registration endpoint (RFC 7591)
# Allows OAuth clients (Claude.ai, Claude Desktop) to self-register
# without requiring manual client_id/secret configuration.
module Oauth
  class RegistrationsController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection
    rate_limit to: 10, within: 1.minute

    def create
      params = parse_json_body
      return unless params

      errors = validate_client_metadata(params)
      if errors.any?
        return render json: errors.first, status: :bad_request
      end

      application = build_application(params)

      if application.save
        render json: registration_response(application, params), status: :created
      else
        render json: {
          error: "invalid_client_metadata",
          error_description: application.errors.full_messages.join(", ")
        }, status: :bad_request
      end
    end

    private

    def parse_json_body
      JSON.parse(request.body.read)
    rescue JSON::ParserError
      render json: {
        error: "invalid_client_metadata",
        error_description: "Request body must be valid JSON"
      }, status: :bad_request
      nil
    end

    def validate_client_metadata(params)
      errors = []

      # redirect_uris is required
      redirect_uris = params["redirect_uris"]
      if redirect_uris.blank? || !redirect_uris.is_a?(Array)
        errors << { error: "invalid_redirect_uri", error_description: "redirect_uris must be a non-empty array" }
        return errors
      end

      redirect_uris.each do |uri_str|
        uri = URI.parse(uri_str)
        unless uri.scheme.in?(%w[https http]) && (uri.scheme == "https" || uri.host.in?(%w[localhost 127.0.0.1]))
          errors << { error: "invalid_redirect_uri", error_description: "Redirect URIs must be HTTPS or localhost. Invalid: #{uri_str}" }
        end
      rescue URI::InvalidURIError
        errors << { error: "invalid_redirect_uri", error_description: "Invalid URI: #{uri_str}" }
      end

      # grant_types must be authorization_code if specified
      grant_types = params["grant_types"]
      if grant_types.present? && grant_types != [ "authorization_code" ]
        errors << { error: "invalid_client_metadata", error_description: "Only authorization_code grant type is supported" }
      end

      # response_types must be code if specified
      response_types = params["response_types"]
      if response_types.present? && response_types != [ "code" ]
        errors << { error: "invalid_client_metadata", error_description: "Only code response type is supported" }
      end

      # token_endpoint_auth_method validation
      auth_method = params["token_endpoint_auth_method"]
      if auth_method.present? && !auth_method.in?(%w[none client_secret_post client_secret_basic])
        errors << { error: "invalid_client_metadata", error_description: "Unsupported token_endpoint_auth_method: #{auth_method}" }
      end

      errors
    end

    def build_application(params)
      auth_method = params["token_endpoint_auth_method"] || "client_secret_basic"
      is_public = auth_method == "none"

      attrs = {
        name: params["client_name"].presence || "Dynamic Client",
        redirect_uri: params["redirect_uris"].join("\n"),
        scopes: "",
        confidential: !is_public,
        registration_type: "dcr",
        client_uri: params["client_uri"],
        logo_uri: params["logo_uri"]
      }

      # Public clients don't get a secret
      attrs[:secret] = nil if is_public

      Doorkeeper::Application.new(attrs)
    end

    def registration_response(application, params)
      response = {
        client_id: application.uid,
        client_name: application.name,
        redirect_uris: params["redirect_uris"],
        grant_types: [ "authorization_code" ],
        response_types: [ "code" ],
        token_endpoint_auth_method: params["token_endpoint_auth_method"] || "client_secret_basic",
        client_id_issued_at: application.created_at.to_i
      }

      if application.confidential?
        response[:client_secret] = application.plaintext_secret || application.secret
        response[:client_secret_expires_at] = 0
      end

      response[:client_uri] = application.client_uri if application.client_uri.present?
      response[:logo_uri] = application.logo_uri if application.logo_uri.present?

      response
    end
  end
end
