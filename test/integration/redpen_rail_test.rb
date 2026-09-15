require "test_helper"

# The reader's page carries nothing of the red pen; the author's page carries the frame
# that fetches it. HTML pages, served verbatim, get the rail spliced in for the author
# only — a reader's bytes are the stored bytes.
class RedpenRailTest < ActionDispatch::IntegrationTest
  test "a reader's post has no rail" do
    get post_url(posts(:published), trailing_slash: true)
    assert_response :success
    assert_select "turbo-frame#notes", count: 0
    assert_select "link[rel=stylesheet][href*=redpen]", count: 0
    assert_select "script[type=module]", text: 'import "redpen"', count: 0
    assert_select "link[rel=modulepreload][href*=redpen]", count: 0
  end

  test "the author's post has the rail pointed at its own path" do
    sign_in_as users(:nityesh)
    get post_url(posts(:published), trailing_slash: true)
    assert_response :success
    assert_select "turbo-frame#notes[src=?][data-controller=redpen]", writing_notes_path(path: "/#{posts(:published).slug}/")
    assert_select "link[rel=stylesheet][href*=redpen]"
  end

  test "the author's homepage has the rail too" do
    sign_in_as users(:nityesh)
    get root_url
    assert_select "turbo-frame#notes[src=?]", writing_notes_path(path: "/")
  end

  test "an HTML page is served byte-for-byte to a reader" do
    get post_url(posts(:html_page), trailing_slash: true)
    assert_equal posts(:html_page).raw_html, response.body
  end

  test "an HTML page gets the rail spliced before </body> for the author" do
    sign_in_as users(:nityesh)
    get post_url(posts(:html_page), trailing_slash: true)
    assert_response :success
    assert_select "turbo-frame#notes[src=?]", writing_notes_path(path: "/#{posts(:html_page).slug}/")
    assert_select "link[rel=stylesheet][href*=redpen]"
    assert_select "script[type=importmap]"
    assert_select "script[type=module]", text: 'import "redpen"'
    assert_match(/Turbo\.session\.drive = false.*<\/body>/m, response.body)
    assert response.body.start_with?(posts(:html_page).raw_html.split("</body>").first), "the document precedes the rail untouched"
  end

  test "an HTML page with no body tag gets the rail appended" do
    sign_in_as users(:nityesh)
    page = HtmlPage.create!(title: "Bare", raw_html: "<html><head><title>Bare</title></head>hello</html>")
    page.publish_now
    get post_url(page, trailing_slash: true)
    assert response.body.start_with?(page.raw_html)
    assert_select "turbo-frame#notes"
  end
end
