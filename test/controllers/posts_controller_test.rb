require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "index renders the homepage sections without auth" do
    get root_url
    assert_response :success
    assert_select "section#apps"
    assert_select "section#library"
    assert_select "section#subscribe"
  end

  test "index shows the postcard apps" do
    get root_url
    assert_select "a.postcard[href=?]", "https://myspool.xyz"
    assert_select "a.postcard[href=?]", "https://teachmesomething.xyz"
    assert_select "a.postcard[href=?]", "https://curatedconnections.io"
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
