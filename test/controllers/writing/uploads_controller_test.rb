require "test_helper"

class Writing::UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token = users(:nityesh).api_tokens.create!(name: "uploader")
    @png = fixture_file_upload("feature.png", "image/png")
  end

  def bearer(token = @token.plain_token)
    { "Authorization" => "Bearer #{token}" }
  end

  test "valid bearer + png stores a blob and returns url + figure_html" do
    assert_difference -> { ActiveStorage::Blob.count }, 1 do
      post writing_uploads_url, params: { file: @png, alt: "A cat", caption: "Meow" }, headers: bearer
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_match %r{\Ahttps://#{Regexp.escape(Setting.current.production_host)}/rails/active_storage/blobs/redirect/}, json["url"]
    assert_includes json["figure_html"], "kg-image-card"
    assert_includes json["figure_html"], "<figcaption>Meow</figcaption>"
  end

  test "missing token is 401" do
    post writing_uploads_url, params: { file: @png }
    assert_response :unauthorized
  end

  test "invalid token is 401" do
    post writing_uploads_url, params: { file: @png }, headers: bearer("not-a-real-token")
    assert_response :unauthorized
  end

  test "expired token is 401" do
    @token.update!(expires_at: 1.hour.ago)
    post writing_uploads_url, params: { file: @png }, headers: bearer
    assert_response :unauthorized
  end

  test "does not accept the session cookie in place of a bearer token" do
    sign_in_as users(:nityesh)
    post writing_uploads_url, params: { file: @png }
    assert_response :unauthorized
  end

  test "missing file is 422" do
    post writing_uploads_url, headers: bearer
    assert_response :unprocessable_entity
  end

  test "a non-image file is 422" do
    json = fixture_file_upload("ghost_export_sample.json", "application/json")
    post writing_uploads_url, params: { file: json }, headers: bearer
    assert_response :unprocessable_entity
  end

  test "an oversize file is 422" do
    big = Tempfile.new([ "big", ".png" ])
    big.binmode
    big.write("x" * (Writing::UploadsController::MAX_BYTES + 1))
    big.rewind

    post writing_uploads_url,
      params: { file: Rack::Test::UploadedFile.new(big.path, "image/png") },
      headers: bearer
    assert_response :unprocessable_entity
  ensure
    big&.close!
  end
end
