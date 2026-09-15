require "test_helper"

class ExplorablesControllerTest < ActionDispatch::IntegrationTest
  INDEX = %(<!DOCTYPE html>\n<html lang="en"><head><title>Hotwire</title><link rel="stylesheet" href="shared/style.css"></head><body>front</body></html>\n)

  setup do
    @explorable = Explorable.create!(title: "Hotwire", slug: "hotwire", raw_html: INDEX)
    @explorable.write_files([
      { path: "shared/style.css", content: "body{color:red}" },
      { path: "decks/index.html", content: "<html><head><title>Decks</title></head><body>decks</body></html>" },
      { path: "decks/10-drive.html", content: "<html><head><title>Drive</title></head><body>drive</body></html>" },
      { path: "img/pixel.png", content: "\x89PNG\r\n\x1a\n".b },
      { path: "shared/engine.js", content: "console.log(1)" }
    ])
    @explorable.publish_now
  end

  test "the front door is index.html, served verbatim through the post route" do
    get "/hotwire/"
    assert_response :success
    assert_equal INDEX, response.body
  end

  test "index.html by name is just another file, and so is the root" do
    get "/hotwire/index.html"
    assert_response :success
    assert_equal INDEX, response.body
  end

  test "a changed file changes the front door's ETag" do
    get "/hotwire/"
    etag = response.headers["ETag"]
    @explorable.write_files([ { path: "shared/style.css", content: "body{color:blue}" } ])
    get "/hotwire/", headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "every file answers at its authored path with its own content type" do
    get "/hotwire/shared/style.css"
    assert_response :success
    assert_equal "text/css", response.media_type
    assert_equal "body{color:red}", response.body

    get "/hotwire/decks/10-drive.html"
    assert_equal "text/html", response.media_type
    assert_includes response.body, "drive"

    # A script from a <script src> is a plain GET for JavaScript, which Rails' forgery guard
    # 422s by default; this is the request every deck makes.
    get "/hotwire/shared/engine.js"
    assert_response :success
    assert_equal "text/javascript", response.media_type

    get "/hotwire/img/pixel.png"
    assert_equal "image/png", response.media_type
    assert_equal "\x89PNG\r\n\x1a\n".b, response.body.b
  end

  test "a directory serves its index, with the trailing slash the rest of the site insists on" do
    get "/hotwire/decks"
    assert_redirected_to "/hotwire/decks/"

    get "/hotwire/decks/"
    assert_response :success
    assert_includes response.body, "decks"
  end

  test "files are ETagged so a reload is a 304" do
    get "/hotwire/shared/style.css"
    etag = response.headers["ETag"]
    get "/hotwire/shared/style.css", headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "a file the bundle doesn't have is a 404, and so is one on a post that isn't an explorable" do
    get "/hotwire/shared/missing.css"
    assert_response :not_found

    get "/#{posts(:published).slug}/anything.css"
    assert_response :not_found
  end

  test "a draft is invisible to the public — front door and files alike" do
    @explorable.unpublish

    get "/hotwire/"
    assert_response :not_found
    get "/hotwire/shared/style.css"
    assert_response :not_found
  end

  test "a signed-in writer previews a draft at its real URL, files included" do
    @explorable.unpublish
    sign_in_as users(:nityesh)

    get "/hotwire/"
    assert_response :success
    # The writer's copy carries the red pen spliced before </body>; the document itself is untouched.
    assert response.body.start_with?(INDEX.split("</body>").first)
    assert response.body.end_with?("</body></html>\n")
    get "/hotwire/shared/style.css"
    assert_response :success
  end

  test "a signed-in writer still can't read a draft article at its URL" do
    sign_in_as users(:nityesh)
    get "/#{posts(:draft).slug}/"
    assert_response :not_found
  end

  test "the writing preview link lands on the real URL, where the relative links resolve" do
    sign_in_as users(:nityesh)
    get writing_explorable_url(@explorable)
    assert_redirected_to "/hotwire/"
  end

  test "the editor lists the files and flags the ones the bundle references but lacks" do
    sign_in_as users(:nityesh)
    get edit_writing_explorable_url(@explorable)
    assert_response :success
    assert_select ".file-list__path[href=?]", "/hotwire/decks/10-drive.html"
    assert_select ".editor-panel__note--warn", count: 0

    @explorable.update!(raw_html: INDEX.sub("shared/style.css", "shared/gone.css"))
    get edit_writing_explorable_url(@explorable)
    assert_select ".editor-panel__note--warn code", text: "shared/gone.css"
  end

  test "the editor saves index.html and publishes through its own nested resource" do
    sign_in_as users(:nityesh)
    patch writing_explorable_url(@explorable), params: { explorable: { raw_html: INDEX.sub("front", "door") } }
    assert_redirected_to edit_writing_explorable_url(@explorable)
    assert_includes @explorable.reload.raw_html, "door"

    delete writing_explorable_publishing_url(@explorable)
    assert @explorable.reload.draft?
    post writing_explorable_publishing_url(@explorable)
    assert @explorable.reload.published?
  end

  test "the HTML-page editor doesn't claim an explorable" do
    sign_in_as users(:nityesh)
    get edit_writing_html_page_url(@explorable)
    assert_response :not_found
  end

  test "the dashboard files it under its own tab" do
    sign_in_as users(:nityesh)
    get writing_root_url
    assert_select ".dash-tab[data-status=explorable] .dash-tab__count", text: "1"
    assert_select ".dash-row[data-status=explorable] a[href=?]", edit_writing_explorable_path(@explorable)
  end
end
