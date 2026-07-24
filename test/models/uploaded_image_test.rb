require "test_helper"

class UploadedImageTest < ActiveSupport::TestCase
  setup do
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("feature.png").open,
      filename: "feature.png",
      content_type: "image/png"
    )
  end

  test "url is a permanent absolute blob-redirect URL on the production host" do
    url = UploadedImage.new(@blob).url
    assert_match %r{\Ahttps://#{Regexp.escape(Setting.current.production_host)}/rails/active_storage/blobs/redirect/}, url
  end

  test "figure_html mirrors the Ghost kg-image-card shape with alt and caption" do
    html = UploadedImage.new(@blob, alt: "A cat", caption: "My cat").figure_html

    assert_includes html, %(<figure class="kg-card kg-image-card kg-card-hascaption">)
    assert_includes html, %(alt="A cat")
    assert_includes html, "<figcaption>My cat</figcaption>"
    assert_includes html, UploadedImage.new(@blob).url
  end

  test "figure_html omits alt and figcaption when absent, and the hascaption class" do
    html = UploadedImage.new(@blob).figure_html

    assert_includes html, %(<figure class="kg-card kg-image-card">)
    refute_includes html, "alt="
    refute_includes html, "figcaption"
  end

  test "escapes caption and alt" do
    html = UploadedImage.new(@blob, alt: %(a"b), caption: "<b>x</b>").figure_html

    assert_includes html, "&lt;b&gt;x&lt;/b&gt;"
    assert_includes html, "a&quot;b"
  end
end
