require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "the dashboard pill sits with the red pen, for the signed-in writer only" do
    get root_url
    assert_select "a[href=?]", "/writing/", count: 0

    sign_in_as users(:nityesh)
    get root_url
    assert_select ".nav a[href=?]", "/writing/", count: 0
    assert_select "a.redpen-dashboard[href=?]", "/writing/"
  end

  test "an article offers its editor to the signed-in writer only" do
    get "/a-published-post/"
    assert_select ".edit-pill", count: 0

    sign_in_as users(:nityesh)
    get "/a-published-post/"
    assert_select "a.edit-pill[href=?]", edit_writing_post_path(posts(:published))
  end

  # Both writer-only controls are back-office chrome, not part of the reader's
  # page — one shared class carries that treatment, so it can't drift apart.
  test "the writer's controls wear the admin styling, not the reader's" do
    sign_in_as users(:nityesh)

    get root_url
    assert_select "a.redpen-dashboard.admin-link[href=?]", "/writing/"

    get "/a-published-post/"
    assert_select "a.edit-pill.admin-link[href=?]", edit_writing_post_path(posts(:published))
  end

  test "a page's edit pill points at the page editor" do
    sign_in_as users(:nityesh)
    get "/about/"
    assert_select "a.edit-pill[href=?]", edit_writing_page_path(posts(:about))
  end

  test "signing in invalidates the anonymous conditional GET" do
    get "/a-published-post/"
    etag = response.headers["ETag"]

    sign_in_as users(:nityesh)
    get "/a-published-post/", headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "show renders a published post" do
    get post_url(posts(:published), trailing_slash: true)
    assert_response :success
    assert_select "h1", text: posts(:published).title
  end

  test "show renders a published page (STI) at its slug" do
    get post_url(posts(:about), trailing_slash: true)
    assert_response :success
  end

  # A page is laid out as the house's front matter, not as an article: its title heads the
  # page, its prose sits beside the numbers, and none of the article chrome shows.
  test "a page renders its title in the page header, not as an article title" do
    get post_url(posts(:about), trailing_slash: true)
    assert_select ".ph h1", text: posts(:about).title
    assert_select ".ph .kick", text: "About this house"
    assert_select "h1.gh-article-title", count: 0
    assert_select ".gh-article-meta", count: 0
  end

  test "a page shows the house by the numbers beside its prose" do
    get post_url(posts(:about), trailing_slash: true)
    assert_select ".essays main.prose#page_#{posts(:about).id}"
    assert_select ".lineage a[href=?]", "/", text: /Ships\s*6/
    assert_select ".lineage a[href=?]", "/apps/", text: /Apps in print\s*1/
    assert_select ".lineage a[href=?]", "/explorables/", text: /Explorables\s*1/
    assert_select ".lineage a[href=?]", "/essays/", text: /Essays, 2 eras\s*1/
    assert_select ".lineage a[href=?]", "https://github.com/nityeshaga/chronicles", text: /Lines of Rails running this\s*[\d,]+/
    assert_select ".lineage.elsewhere a", count: 2
    assert_select ".lineage.elsewhere a[href=?]", "https://x.com/nityeshaga"
    assert_select ".lineage.elsewhere a[href=?]", "https://github.com/nityeshaga"
  end

  # A ship logged tonight changes the about page without touching the page.
  test "a page's ETag moves with the house's numbers" do
    get post_url(posts(:about), trailing_slash: true)
    etag = response.headers["ETag"]
    get post_url(posts(:about), trailing_slash: true), headers: { "If-None-Match" => etag }
    assert_response :not_modified

    ships(:drafted).publish
    get post_url(posts(:about), trailing_slash: true), headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "an article still renders its article title" do
    get post_url(posts(:published), trailing_slash: true)
    assert_select "h1.gh-article-title", text: posts(:published).title
  end

  # --- HTML pages: the stored document IS the response. Asserted byte-for-byte
  #     rather than with assert_select, because verbatim is the entire contract. ---
  test "show serves a published HTML page as the exact stored document" do
    get post_url(posts(:html_page), trailing_slash: true)
    assert_response :success
    assert_equal posts(:html_page).raw_html, response.body
  end

  test "an HTML page carries no layout markup" do
    get post_url(posts(:html_page), trailing_slash: true)
    assert_select "header.gh-head", count: 0
    assert_select "footer", count: 0
    assert_no_match %r{/assets/application}, response.body
  end

  test "show 404s for a draft HTML page" do
    draft = HtmlPage.create!(title: "Unfinished Landing Page", raw_html: "<html><body>soon</body></html>")
    get post_url(draft, trailing_slash: true)
    assert_response :not_found
  end

  test "an HTML page is ETagged and answers 304 to a matching If-None-Match" do
    get post_url(posts(:html_page), trailing_slash: true)
    etag = response.headers["ETag"]
    assert etag.present?
    get post_url(posts(:html_page), trailing_slash: true), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "show 404s for a draft" do
    get post_url(posts(:draft), trailing_slash: true)
    assert_response :not_found
  end

  test "noindex header is set off the production host" do
    host! "preview.example.com"
    get root_url
    assert_equal "noindex", response.headers["X-Robots-Tag"]
  end

  test "noindex header is absent on the production host" do
    host! Setting.current.production_host
    get root_url
    assert_nil response.headers["X-Robots-Tag"]
  end

  test "404 page carries the parity title" do
    get "/does-not-exist/"
    assert_response :not_found
    assert_select "title", text: "404 — Page not found"
  end

  test "bare slug 301s to the trailing-slash form" do
    get post_url(posts(:published))
    assert_response :moved_permanently
    assert_redirected_to post_url(posts(:published), trailing_slash: true)
  end

  test "retired paginated archive 301s to home" do
    get "/page/2/"
    assert_response :moved_permanently
    assert_redirected_to "/"
  end

  test "retired tag pagination 301s to the tag page" do
    get "/tag/rails/page/3/"
    assert_response :moved_permanently
    assert_redirected_to "/tag/rails/"
  end

  test "retired amp page 301s to the canonical post" do
    get "/a-published-post/amp/"
    assert_response :moved_permanently
    assert_redirected_to "/a-published-post/"
  end

  test "author archive 301s to about" do
    get "/author/nityesh/"
    assert_redirected_to "/about/"
  end

  test "www 301s to the apex with path and query preserved" do
    host = Setting.current.production_host
    host! "www.#{host}"
    get "/a-published-post/?utm_source=x"
    assert_response :moved_permanently
    assert_redirected_to "https://#{host}/a-published-post/?utm_source=x"
  end

  test "www root 301s to the apex root" do
    host = Setting.current.production_host
    host! "www.#{host}"
    get "/"
    assert_response :moved_permanently
    assert_redirected_to "https://#{host}/"
  end

  test "rss feed renders" do
    get "/rss/"
    assert_response :success
    assert_match "A Published Post", response.body
  end
end
