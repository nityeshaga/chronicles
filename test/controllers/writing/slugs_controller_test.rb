require "test_helper"

class Writing::SlugsControllerTest < ActionDispatch::IntegrationTest
  test "asking requires authentication" do
    get writing_slug_url("anything")
    assert_redirected_to new_session_url
  end

  test "a name nobody holds is available" do
    sign_in_as users(:nityesh)
    get writing_slug_url("a-name-nobody-holds")
    assert_select "turbo-frame#slug-status span[data-state=?]", "available", text: "Available"
  end

  test "a slug an article already holds is taken" do
    sign_in_as users(:nityesh)
    get writing_slug_url(posts(:published).slug)
    assert_select "turbo-frame#slug-status span[data-state=?]", "taken", text: "Taken"
  end

  # Posts, pages and HTML pages share one table and one uniqueness constraint, so the
  # answer can't care which kind is sitting on the name.
  test "a page's slug is taken just the same" do
    sign_in_as users(:nityesh)
    get writing_slug_url(posts(:about).slug)
    assert_select "turbo-frame#slug-status span[data-state=?]", "taken"

    get writing_slug_url(posts(:html_page).slug)
    assert_select "turbo-frame#slug-status span[data-state=?]", "taken"
  end

  # Otherwise every editor would open declaring its own URL taken.
  test "the record being edited doesn't take its own slug" do
    sign_in_as users(:nityesh)
    get writing_slug_url(posts(:published).slug, except: posts(:published).slug)
    assert_select "turbo-frame#slug-status span[data-state=?]", "available"
  end

  # Posts are served from the root, so the router — not a hand-kept list — knows which
  # names are already spoken for.
  test "a name another route answers to is reserved" do
    sign_in_as users(:nityesh)
    %w[ rss writing up sitemap.xml ].each do |reserved|
      get writing_slug_url(reserved)
      assert_select "turbo-frame#slug-status span[data-state=?]", "reserved"
    end
  end

  # The editor never asks about a blank slug; if something does, it gets an empty frame
  # rather than a verdict. Hand-built path: the helper would escape the escape.
  test "a blank slug says nothing at all" do
    sign_in_as users(:nityesh)
    get "/writing/slugs/%20"
    assert_select "turbo-frame#slug-status"
    assert_select "turbo-frame#slug-status span", count: 0
  end
end
