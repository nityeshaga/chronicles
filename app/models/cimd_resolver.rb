# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Resolves a Client ID Metadata Document (CIMD) for OAuth clients
# that use a URL as their client_id.
#
# Per the MCP spec (2025-11-25), when a client presents an HTTPS URL
# as its client_id, the authorization server fetches the metadata
# document from that URL to learn redirect_uris, client_name, etc.
#
# The resolved application is cached as a Doorkeeper::Application row
# and re-fetched when stale (older than CACHE_TTL).
class CimdResolver
  CACHE_TTL = 1.hour
  FETCH_TIMEOUT = 5 # seconds
  MAX_BODY_SIZE = 100.kilobytes

  class ResolutionError < StandardError; end

  def initialize(client_id_url)
    @client_id_url = client_id_url
  end

  def resolve
    # Return cached application if fresh
    existing = Doorkeeper::Application.find_by(uid: @client_id_url, registration_type: "cimd")
    if existing && existing.metadata_cached_at && existing.metadata_cached_at > CACHE_TTL.ago
      return existing
    end

    # Fetch and validate the metadata document
    metadata = fetch_metadata
    return nil unless metadata

    errors = validate_metadata(metadata)
    if errors.any?
      Rails.logger.warn("CIMD validation failed for #{@client_id_url}: #{errors.join(', ')}")
      return nil
    end

    # Create or update the cached application
    persist_application(metadata, existing)
  rescue ResolutionError => e
    Rails.logger.warn("CIMD resolution failed for #{@client_id_url}: #{e.message}")
    nil
  end

  private

  def fetch_metadata
    uri = URI.parse(@client_id_url)
    unless uri.scheme == "https" || (uri.host.in?(%w[localhost 127.0.0.1]) && Rails.env.development?)
      raise ResolutionError, "CIMD URL must be HTTPS"
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = FETCH_TIMEOUT
    http.read_timeout = FETCH_TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise ResolutionError, "HTTP #{response.code} fetching metadata"
    end

    if response.body.bytesize > MAX_BODY_SIZE
      raise ResolutionError, "Response body exceeds #{MAX_BODY_SIZE} bytes"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError
    raise ResolutionError, "Invalid JSON in metadata document"
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise ResolutionError, "Timeout fetching metadata"
  rescue SocketError, Errno::ECONNREFUSED => e
    raise ResolutionError, "Connection failed: #{e.message}"
  end

  def validate_metadata(metadata)
    errors = []

    # client_id must match the URL
    if metadata["client_id"] != @client_id_url
      errors << "client_id in document (#{metadata['client_id']}) does not match URL (#{@client_id_url})"
    end

    # redirect_uris must be present
    redirect_uris = metadata["redirect_uris"]
    if redirect_uris.blank? || !redirect_uris.is_a?(Array)
      errors << "redirect_uris must be a non-empty array"
      return errors
    end

    # Each redirect URI must be HTTPS or localhost
    redirect_uris.each do |uri_str|
      uri = URI.parse(uri_str)
      unless uri.scheme.in?(%w[https http]) && (uri.scheme == "https" || uri.host.in?(%w[localhost 127.0.0.1]))
        errors << "Invalid redirect URI: #{uri_str} (must be HTTPS or localhost)"
      end
    rescue URI::InvalidURIError
      errors << "Invalid URI format: #{uri_str}"
    end

    errors
  end

  def persist_application(metadata, existing)
    app = existing || Doorkeeper::Application.new(uid: @client_id_url)

    app.assign_attributes(
      name: metadata["client_name"].presence || URI.parse(@client_id_url).host,
      redirect_uri: metadata["redirect_uris"].join("\n"),
      scopes: "",
      confidential: false,
      secret: nil,
      registration_type: "cimd",
      client_uri: metadata["client_uri"],
      logo_uri: metadata["logo_uri"],
      metadata_cached_at: Time.current
    )

    app.save!
    app
  rescue ActiveRecord::RecordNotUnique
    # Race condition: another request created it first, return that one
    Doorkeeper::Application.find_by(uid: @client_id_url)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("CIMD persist failed for #{@client_id_url}: #{e.message}")
    nil
  end
end
