# frozen_string_literal: true

require "net/http"

# Server-side fetch for upload_image and upload_ship_media: agents hand over a URL, never
# bytes, so a photo or a clip never lands as base64 in the model's context window. Guards
# every failure mode with a recovery-oriented message. http_get is the single seam the
# tests stub — no webmock, no network in the suite.
module MediaFetching
  MAX_IMAGE_BYTES = 10.megabytes
  MAX_VIDEO_BYTES = 50.megabytes
  MAX_REDIRECTS = 3
  TIMEOUT = 15

  FetchedFile = Struct.new(:bytes, :content_type, keyword_init: true)

  private
    def fetch_remote_image(source_url)
      fetch_remote_file(source_url, types: %w[ image/ ], max_bytes: MAX_IMAGE_BYTES, expected: "an image")
    end

    # Returns a FetchedFile on success or a { error: } hash the tool passes straight through.
    # types are Content-Type prefixes ("image/", "video/mp4"); expected names them for the error.
    def fetch_remote_file(source_url, types:, max_bytes:, expected:)
      uri = parse_http_uri(source_url)
      return { error: "source_url must be an http:// or https:// URL." } unless uri

      redirects = 0
      loop do
        response = http_get(uri)
        case response
        when Net::HTTPRedirection
          redirects += 1
          return { error: "source_url made more than #{MAX_REDIRECTS} redirects. Link directly to the file." } if redirects > MAX_REDIRECTS

          uri = parse_http_uri(response["location"])
          return { error: "source_url redirected to a non-http(s) location." } unless uri
        when Net::HTTPSuccess
          return validate_file(response, types: types, max_bytes: max_bytes, expected: expected)
        else
          return { error: "Fetching source_url failed (HTTP #{response.code}). Confirm the URL is public and reachable." }
        end
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      { error: "Fetching source_url timed out after #{TIMEOUT}s. Try a smaller or faster-loading file." }
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      { error: "Could not reach source_url (#{e.class}). Check the URL and try again." }
    end

    def validate_file(response, types:, max_bytes:, expected:)
      content_type = response.content_type.to_s
      unless types.any? { |type| content_type.start_with?(type) }
        return { error: "source_url did not return #{expected} (Content-Type: #{content_type.presence || "unknown"}). Link directly to the file." }
      end

      declared = response["content-length"].to_i
      return oversize_error(declared, max_bytes) if declared > max_bytes

      bytes = response.body.to_s
      return oversize_error(bytes.bytesize, max_bytes) if bytes.bytesize > max_bytes

      FetchedFile.new(bytes: bytes, content_type: content_type)
    end

    def oversize_error(size, max_bytes)
      { error: "File is #{(size / 1.megabyte.to_f).round(1)} MB, over the #{max_bytes / 1.megabyte} MB limit. Use a smaller one." }
    end

    # The name to store the blob under: the caller's, else the URL's last segment, else
    # one derived from the content type ("image.jpeg", "video.mp4").
    def filename_for(source_url, content_type, provided)
      return provided.strip if provided.present?

      base = File.basename(URI.parse(source_url).path.to_s)
      return base if base.present? && base.include?(".")

      "#{content_type.split("/").first}.#{content_type.split("/").last.split("+").first}"
    rescue URI::InvalidURIError
      "#{content_type.split("/").first}.#{content_type.split("/").last.split("+").first}"
    end

    def parse_http_uri(value)
      uri = URI.parse(value.to_s)
      uri if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end

    def http_get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
    end
end
