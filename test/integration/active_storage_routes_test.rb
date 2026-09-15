require "test_helper"

# Active Storage draws its routes after the app's, so a catch-all like /:slug/*path
# would swallow /rails/active_storage/... before the engine sees it. That is what
# happened when explorable files got their route: every uploaded image and every
# ship preview 404'd in production. These pin the blob URLs to the engine.
class ActiveStorageRoutesTest < ActionDispatch::IntegrationTest
  setup do
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("not really a png"), filename: "pixel.png", content_type: "image/png"
    )
  end

  test "the redirect URL reaches Active Storage, not the explorables catch-all" do
    get rails_blob_path(@blob)
    assert_response :redirect
  end

  test "the proxy URL streams the blob" do
    get rails_storage_proxy_path(@blob)
    assert_response :success
    assert_equal "image/png", response.media_type
  end
end
