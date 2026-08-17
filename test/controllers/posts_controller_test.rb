require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "index renders the homepage sections without auth" do
    get root_url
    assert_response :success
    assert_select "section#apps"
    assert_select "section#library"
    assert_select "section#subscribe"
  end

  test "index shelves every machine newest-updated first, each shot linking out" do
    get root_url
    shots = css_select(".machine .machine-shot").map { |a| a["href"] }
    assert_equal Machine.all.map(&:url), shots
  end

  test "the workshop section is gone — open source shelves with everything else" do
    get root_url
    assert_select "section#source", count: 0
    assert_select ".machine-title a[href=?]", "https://github.com/nityeshaga/claude-home-base"
  end

  test "index leads with the latest published articles" do
    get root_url
    assert_select "#press .press-title a[href=?]", "/#{posts(:published).slug}/", text: posts(:published).title
    # Drafts stay off the press strip.
    assert_select "#press .press-title a", text: posts(:draft).title, count: 0
  end

  # The masthead nav advertises destinations, not scroll positions: an in-page
  # anchor dressed as a site section is a lie the reader only catches after
  # clicking. About isn't there either — the homepage already sends readers to it.
  test "the masthead nav offers real destinations only" do
    get root_url
    assert_select ".mast-nav a[href=?]", "/about/", count: 0
    assert_select ".mast-nav a[href=?]", "/#apps", count: 0
    assert_select ".mast-nav a[href=?]", "/#library", count: 0
  end

  test "the masthead offers the dashboard to the signed-in writer only" do
    get root_url
    assert_select ".mast-nav a[href=?]", "/writing/", count: 0

    sign_in_as users(:nityesh)
    get root_url
    assert_select ".mast-nav a[href=?]", "/writing/"
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
    assert_select ".mast-nav a.admin-link[href=?]", "/writing/"

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

  test "index shelves eras that have published articles, linking to their tag pages" do
    get root_url
    # chronicles is an era fixture with a published article → a book on the shelf.
    assert_select ".shelf-books a.book[href=?]", "/tag/chronicles/"
  end

  test "index omits eras with no published articles" do
    get root_url
    # past-life is an era fixture but has no published article → no book.
    assert_select ".shelf-books a.book[href=?]", "/tag/past-life/", count: 0
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

  test "a page does not render the internal-name article title" do
    get post_url(posts(:about), trailing_slash: true)
    assert_select "h1.gh-article-title", count: 0
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
