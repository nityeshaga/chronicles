require "test_helper"

# Every image a body can hold — an editor upload, two uploads in a row, an image the body
# only points at — reaches the public page as the one figure the importer wrote for Ghost
# images and the public CSS styles: kg-image-card. No more Trix "filename 3.2 MB" captions.
class ImageCardRenderingTest < ActionDispatch::IntegrationTest
  include ActionView::Helpers::TagHelper

  setup do
    sign_in_as users(:nityesh)
    @draft = posts(:draft)
    @blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("feature.png").open, filename: "feature.png", content_type: "image/png")
  end

  # The node Lexxy exports for an upload (presentation=gallery rides on every image).
  def upload(caption: nil, alt: "feature.png")
    attributes = { sgid: @blob.attachable_sgid, "content-type": "image/png", alt:, caption:, width: 640, height: 480, presentation: "gallery" }.compact
    tag.send("action-text-attachment", "", **attributes)
  end

  def publish(body)
    patch writing_post_url(@draft), params: { post: { body: } }
    post writing_post_publishing_url(@draft)
    get post_url(@draft.reload)
    follow_redirect!
  end

  test "an upload is a kg-image-card with alt and srcset, and no filename caption" do
    publish upload

    assert_select "figure.kg-card.kg-image-card:not(.kg-card-hascaption)", 1
    assert_select "figure.kg-image-card img.kg-image[alt='feature.png'][loading='lazy'][width='640'][height='480']", 1
    assert_select "figure.kg-image-card img[srcset*='720w'][srcset*='1440w'][sizes]", 1
    assert_select "figcaption", false
    assert_select ".attachment", false
    refute_includes response.body, "KB"
  end

  test "an upload's caption is the figcaption" do
    publish upload(caption: "The feature")

    assert_select "figure.kg-image-card.kg-card-hascaption figcaption", text: "The feature", count: 1
  end

  test "consecutive uploads are a kg-gallery-card" do
    publish "<div>#{upload}#{upload}</div>"

    assert_select "figure.kg-card.kg-gallery-card.kg-width-wide .kg-gallery-container .kg-gallery-image img[srcset]", 2
    assert_select "figure.kg-image-card", false
    assert_select ".attachment-gallery", false
  end

  test "a remote image is the same kg-image-card, caption markup intact" do
    caption = %(Photo by <a href="https://unsplash.com/x">Someone</a>)
    publish tag.send("action-text-attachment", "", url: "https://cdn.example.com/x.jpg", "content-type": "image/*",
      alt: "A cat", caption:, width: 600, height: 400, filename: "x.jpg", presentation: "gallery")

    assert_select "figure.kg-card.kg-image-card.kg-card-hascaption img.kg-image[src='https://cdn.example.com/x.jpg'][alt='A cat'][width='600'][height='400']", 1
    assert_select "figure.kg-image-card figcaption a[href='https://unsplash.com/x']", text: "Someone"
  end

  test "a file that isn't an image is a link" do
    file = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("hello"), filename: "notes.txt", content_type: "text/plain")
    publish tag.send("action-text-attachment", "", sgid: file.attachable_sgid, "content-type": "text/plain", filename: "notes.txt")

    assert_select "a[href*='rails/active_storage']", text: "notes.txt"
    assert_select "figure", false
  end
end
