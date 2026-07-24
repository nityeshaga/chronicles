require "test_helper"

class UploadImageToolTest < ActiveSupport::TestCase
  PNG = "\x89PNG\r\n\x1a\n".b

  setup do
    @user = users(:nityesh)
    Thread.current[:mcp_current_user] = @user
    @tool = UploadImageTool.new
  end

  teardown do
    Thread.current[:mcp_current_user] = nil
  end

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, @tool.call(source_url: "https://example.com/x.png")
  end

  test "fetches, stores a blob, and returns url + figure_html" do
    stub_fetch ImageFetching::FetchedImage.new(bytes: PNG, content_type: "image/png")

    result = nil
    assert_difference -> { ActiveStorage::Blob.count }, 1 do
      result = @tool.call(source_url: "https://example.com/cat.png", alt: "Cat", caption: "Meow")
    end

    assert_match %r{\Ahttps://#{Regexp.escape(Setting.current.production_host)}/rails/active_storage/blobs/redirect/}, result[:url]
    assert_includes result[:figure_html], "kg-image-card"
    assert_includes result[:figure_html], %(alt="Cat")
    assert_includes result[:figure_html], "<figcaption>Meow</figcaption>"
    assert_includes result[:message], "body_patches"
  end

  test "derives the filename from the URL when not given" do
    stub_fetch ImageFetching::FetchedImage.new(bytes: PNG, content_type: "image/png")
    @tool.call(source_url: "https://example.com/photos/sunset.png")

    assert_equal "sunset.png", ActiveStorage::Blob.order(:created_at).last.filename.to_s
  end

  test "derives a filename from the content type when the URL has none" do
    stub_fetch ImageFetching::FetchedImage.new(bytes: PNG, content_type: "image/jpeg")
    @tool.call(source_url: "https://example.com/download")

    assert_equal "image.jpeg", ActiveStorage::Blob.order(:created_at).last.filename.to_s
  end

  test "passes a fetch error straight through" do
    stub_fetch({ error: "boom" })
    assert_equal({ error: "boom" }, @tool.call(source_url: "https://example.com/x"))
  end

  test "rejects a non-http scheme before any network call" do
    result = @tool.send(:fetch_remote_image, "ftp://example.com/x.png")
    assert_match(/http/, result[:error])
  end

  test "rejects a non-image content type" do
    stub_http_get http_response("text/html", "<html>")
    result = @tool.send(:fetch_remote_image, "https://example.com/page")
    assert_match(/did not return an image/, result[:error])
  end

  test "rejects an oversize image" do
    stub_http_get http_response("image/png", "x" * (ImageFetching::MAX_BYTES + 1))
    result = @tool.send(:fetch_remote_image, "https://example.com/huge.png")
    assert_match(/10 MB/, result[:error])
  end

  test "caps redirects" do
    stub_http_get redirect_response("https://example.com/again.png")
    result = @tool.send(:fetch_remote_image, "https://example.com/start.png")
    assert_match(/redirect/i, result[:error])
  end

  # Exercises the REAL http_get seam (no stub): Net::HTTP must be required, or this
  # raises NameError instead of the connection-refused SystemCallError we expect.
  test "http_get resolves Net::HTTP against a closed port" do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close

    assert_raises(SystemCallError) do
      @tool.send(:http_get, URI.parse("http://127.0.0.1:#{port}/x.png"))
    end
  end

  private
    def stub_fetch(value)
      @tool.define_singleton_method(:fetch_remote_image) { |_url| value }
    end

    def stub_http_get(response)
      @tool.define_singleton_method(:http_get) { |_uri| response }
    end

    def http_response(content_type, body)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response["content-type"] = content_type
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, body)
      response
    end

    def redirect_response(location)
      response = Net::HTTPFound.new("1.1", "302", "Found")
      response["location"] = location
      response
    end
end
