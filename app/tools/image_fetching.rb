# frozen_string_literal: true

require "net/http"

# Server-side image fetch for upload_image: agents hand over a URL, never bytes, so
# a photo never lands as base64 in the model's context window. Guards every failure
# mode with a recovery-oriented message. http_get is the single seam the tests stub —
# no webmock, no network in the suite.
module ImageFetching
  MAX_BYTES = 10.megabytes
  MAX_REDIRECTS = 3
  TIMEOUT = 15

  FetchedImage = Struct.new(:bytes, :content_type, keyword_init: true)

  private
    # Returns a FetchedImage on success or a { error: } hash the tool passes straight through.
    def fetch_remote_image(source_url)
      uri = parse_http_uri(source_url)
      return { error: "source_url must be an http:// or https:// URL." } unless uri

      redirects = 0
      loop do
        response = http_get(uri)
        case response
        when Net::HTTPRedirection
          redirects += 1
          return { error: "source_url made more than #{MAX_REDIRECTS} redirects. Link directly to the image file." } if redirects > MAX_REDIRECTS

          uri = parse_http_uri(response["location"])
          return { error: "source_url redirected to a non-http(s) location." } unless uri
        when Net::HTTPSuccess
          return validate_image(response)
        else
          return { error: "Fetching source_url failed (HTTP #{response.code}). Confirm the URL is public and reachable." }
        end
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      { error: "Fetching source_url timed out after #{TIMEOUT}s. Try a smaller or faster-loading image." }
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      { error: "Could not reach source_url (#{e.class}). Check the URL and try again." }
    end

    def validate_image(response)
      content_type = response.content_type.to_s
      unless content_type.start_with?("image/")
        return { error: "source_url did not return an image (Content-Type: #{content_type.presence || "unknown"}). Link directly to an image file." }
      end

      declared = response["content-length"].to_i
      return oversize_error(declared) if declared > MAX_BYTES

      bytes = response.body.to_s
      return oversize_error(bytes.bytesize) if bytes.bytesize > MAX_BYTES

      FetchedImage.new(bytes: bytes, content_type: content_type)
    end

    def oversize_error(size)
      { error: "Image is #{(size / 1.megabyte.to_f).round(1)} MB, over the 10 MB limit. Use a smaller image." }
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
