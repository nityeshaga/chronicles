require "test_helper"

class Writing::HtmlPagesControllerTest < ActionDispatch::IntegrationTest
  DOCUMENT = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head><title>Launch</title></head>
    <body><h1 class="launch-hero">Launch</h1></body>
    </html>
  HTML

  test "new requires authentication" do
    get new_writing_html_page_url
    assert_redirected_to new_session_url
  end

  test "creates an HTML page when signed in" do
    sign_in_as users(:nityesh)
    assert_difference -> { HtmlPage.count }, 1 do
      post writing_html_pages_url, params: { html_page: { title: "Launch", raw_html: DOCUMENT } }
    end
    page = HtmlPage.find_by!(slug: "launch")
    assert_redirected_to edit_writing_html_page_url(page)
    assert_equal DOCUMENT, page.raw_html
  end

  test "edit renders the source in a textarea" do
    sign_in_as users(:nityesh)
    get edit_writing_html_page_url(posts(:html_page))
    assert_response :success
    assert_select "textarea[name=?]", "html_page[raw_html]", text: /Hands on Deck/
  end

  test "the editor carries the slug-status frame" do
    sign_in_as users(:nityesh)
    get edit_writing_html_page_url(posts(:html_page))
    assert_select "turbo-frame#slug-status[data-slug-target=status]"
    assert_select "input[name=?][data-slug-target=slug]", "html_page[slug]"
  end

  # No autosave contract here — saving a whole document is an explicit act — so an
  # ordinary save just lands back on the editor with a notice.
  test "saving edits the stored document and returns to the editor" do
    sign_in_as users(:nityesh)
    page = posts(:html_page)
    patch writing_html_page_url(page), params: { html_page: { raw_html: DOCUMENT } }
    assert_redirected_to edit_writing_html_page_url(page)
    assert_equal DOCUMENT, page.reload.raw_html
  end

  test "renaming the slug redirects to the editor's new URL" do
    sign_in_as users(:nityesh)
    page = posts(:html_page)
    patch writing_html_page_url(page), params: { html_page: { slug: "all-hands" } }
    assert_equal "all-hands", page.reload.slug
    assert_redirected_to edit_writing_html_page_url(page)
  end

  # A fragment would publish as a broken white page, so the model refuses it; the form
  # has to come back with the reason rather than silently dropping the paste.
  test "a fragment re-renders the form with the error" do
    sign_in_as users(:nityesh)
    post writing_html_pages_url, params: { html_page: { title: "Fragment", raw_html: "<h1>hi</h1>" } }
    assert_response :unprocessable_entity
    assert_select "ul.errors li", text: /complete HTML document/
  end

  # Preview is the human half of the point: the same bytes the public renderer will serve,
  # with no layout wrapped around them, while the record is still a draft.
  test "preview returns the stored document with no layout" do
    sign_in_as users(:nityesh)
    page = posts(:html_page)
    page.unpublish

    get writing_html_page_url(page)
    assert_response :success
    assert_equal page.raw_html, response.body
    assert_no_match "writing-app", response.body
  end

  test "preview requires authentication" do
    get writing_html_page_url(posts(:html_page))
    assert_redirected_to new_session_url
  end

  # No ?publishing=open here: this editor has no popover to open, its publishing panel
  # sits on the page already.
  test "publishing resource is nested under HTML pages" do
    sign_in_as users(:nityesh)
    page = posts(:html_page)

    delete writing_html_page_publishing_url(page)
    assert page.reload.draft?
    assert_redirected_to edit_writing_html_page_url(page)

    post writing_html_page_publishing_url(page)
    assert page.reload.published?
    assert_redirected_to edit_writing_html_page_url(page)
  end

  test "destroy removes the HTML page" do
    sign_in_as users(:nityesh)
    assert_difference -> { Post.count }, -1 do
      delete writing_html_page_url(posts(:html_page))
    end
    assert_redirected_to writing_root_url
  end
end
