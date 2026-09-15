require "test_helper"

class UploadShipMediaToolTest < ActiveSupport::TestCase
  PNG = "\x89PNG\r\n\x1a\n".b
  MP4 = "\x00\x00\x00\x18ftypmp42".b

  setup do
    Thread.current[:mcp_current_user] = users(:nityesh)
    @tool = UploadShipMediaTool.new
    @ship = ships(:phone)
  end

  teardown { Thread.current[:mcp_current_user] = nil }

  test "requires authentication" do
    Thread.current[:mcp_current_user] = nil
    assert_equal ToolErrors::AUTH_REQUIRED, @tool.call(id: @ship.id, source_url: "https://example.com/x.mp4")
  end

  test "attaches a video preview and asks for a poster" do
    stub_fetch MediaFetching::FetchedFile.new(bytes: MP4, content_type: "video/mp4")

    result = @tool.call(id: @ship.id, source_url: "https://example.com/clips/prev-123.mp4")

    assert @ship.reload.preview.attached?
    assert_equal "prev-123.mp4", @ship.preview.filename.to_s
    assert_equal "video/mp4", @ship.preview.content_type
    assert_equal :video, result[:media_kind]
    assert_equal MP4.bytesize, result[:byte_size]
    assert_match %r{\Ahttps://#{Regexp.escape(Setting.current.production_host)}/rails/active_storage/blobs/proxy/}, result[:url]
    assert_includes result[:message], "poster"
  end

  test "attaches a poster, replacing the old one" do
    stub_fetch MediaFetching::FetchedFile.new(bytes: PNG, content_type: "image/png")
    @tool.call(id: @ship.id, source_url: "https://example.com/first.png", slot: "poster")
    @tool.call(id: @ship.id, source_url: "https://example.com/second.png", slot: "poster")

    assert_equal "second.png", @ship.reload.poster.filename.to_s
    assert_equal 1, @ship.poster_attachment.class.where(record: @ship, name: "poster").count
  end

  test "an image preview reads as an image and derives a filename from the content type" do
    stub_fetch MediaFetching::FetchedFile.new(bytes: PNG, content_type: "image/jpeg")
    result = @tool.call(id: @ship.id, source_url: "https://example.com/download")

    assert_equal :image, result[:media_kind]
    assert_equal "image.jpeg", @ship.reload.preview.filename.to_s
    assert_equal "Attached.", result[:message]
  end

  test "a poster must be an image, and a preview must be an mp4 or an image" do
    stub_http_get http_response("video/mp4", MP4)
    result = @tool.call(id: @ship.id, source_url: "https://example.com/x.mp4", slot: "poster")
    assert_includes result[:error], "did not return an image"

    stub_http_get http_response("video/webm", MP4)
    result = @tool.call(id: @ship.id, source_url: "https://example.com/x.webm")
    assert_includes result[:error], "an mp4 video or an image"
    assert_not @ship.reload.preview.attached?
  end

  test "caps a preview at the video limit" do
    stub_http_get http_response("video/mp4", "x" * (MediaFetching::MAX_VIDEO_BYTES + 1))
    result = @tool.call(id: @ship.id, source_url: "https://example.com/huge.mp4")
    assert_includes result[:error], "50 MB"
  end

  test "unknown ship, unknown slot" do
    assert_equal ToolErrors::SHIP_NOT_FOUND, @tool.call(id: 0, source_url: "https://example.com/x.mp4")
    assert_includes @tool.call(id: @ship.id, source_url: "https://example.com/x.mp4", slot: "cover")[:error], "slot"
  end

  private
    def stub_fetch(value)
      @tool.define_singleton_method(:fetch_remote_file) { |_url, **| value }
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
end
