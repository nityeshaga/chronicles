require "test_helper"

class Writing::SlugsControllerTest < ActionDispatch::IntegrationTest
  test "asking requires authentication" do
    get writing_slug_url(slug: "anything")
    assert_redirected_to new_session_url
  end

  test "a name nobody holds is available" do
    sign_in_as users(:nityesh)
    get writing_slug_url(slug: "a-name-nobody-holds")
    assert_select "turbo-frame#slug-status span[data-state=?]", "available", text: "Available"
  end

  test "a slug an article already holds is taken" do
    sign_in_as users(:nityesh)
    get writing_slug_url(slug: posts(:published).slug)
    assert_select "turbo-frame#slug-status span[data-state=?]", "taken", text: "Taken"
  end

  # Posts, pages and HTML pages share one table and one uniqueness constraint, so the
  # answer can't care which kind is sitting on the name.
  test "a page's slug is taken just the same" do
    sign_in_as users(:nityesh)
    get writing_slug_url(slug: posts(:about).slug)
    assert_select "turbo-frame#slug-status span[data-state=?]", "taken"

    get writing_slug_url(slug: posts(:html_page).slug)
    assert_select "turbo-frame#slug-status span[data-state=?]", "taken"
  end

  # Otherwise every editor would open declaring its own URL taken. By id, never by a copy
  # of the slug: the copy the editor is holding is stale the moment the record is saved.
  test "the record being edited doesn't take its own slug" do
    sign_in_as users(:nityesh)
    get writing_slug_url(slug: posts(:published).slug, except: posts(:published).id)
    assert_select "turbo-frame#slug-status span[data-state=?]", "available"
  end

  # The path a new post takes: autosave mints the draft mid-session and hands back its id,
  # and from then on the editor asks with it — so the draft stops being told that the slug
  # it was just given is taken.
  test "a draft minted mid-session doesn't take its own slug" do
    sign_in_as users(:nityesh)
    post writing_posts_url, headers: { "X-Autosave" => "true" }, params: { post: { title: "Hello world" } }
    assert_response :created
    minted_id = response.headers["X-Post-Id"]
    assert_equal "hello-world", Post.find(minted_id).slug

    get writing_slug_url(slug: "hello-world")
    assert_select "turbo-frame#slug-status span[data-state=?]", "taken"

    get writing_slug_url(slug: "hello-world", except: minted_id)
    assert_select "turbo-frame#slug-status span[data-state=?]", "available"
  end

  # Posts are served from the root, so the router — not a hand-kept list — knows which
  # names are already spoken for.
  test "a name another route answers to is reserved" do
    sign_in_as users(:nityesh)
    %w[ rss writing up sitemap.xml ].each do |reserved|
      get writing_slug_url(slug: reserved)
      assert_select "turbo-frame#slug-status span[data-state=?]", "reserved"
    end
  end

  # "/notes.md/" recognizes as the post "notes" in the "md" format — a route, but not this
  # post's route, so the name is no good even though nobody holds it.
  test "a name a route would swallow as a format is reserved" do
    sign_in_as users(:nityesh)
    get writing_slug_url(slug: "notes.md")
    assert_select "turbo-frame#slug-status span[data-state=?]", "reserved"
  end

  # A name that can't be a URL at all doesn't route, so it's spoken for by nothing and
  # usable by nobody: same answer.
  test "a name that can't be a URL is reserved" do
    sign_in_as users(:nityesh)
    get writing_slug_url(slug: "two words")
    assert_select "turbo-frame#slug-status span[data-state=?]", "reserved"
  end

  # The editor asks about a blank slug the moment the field is emptied; it gets an empty
  # frame rather than a verdict, which is the whole rule — there isn't a second one in JS.
  test "a blank slug says nothing at all" do
    sign_in_as users(:nityesh)
    get writing_slug_url(slug: " ")
    assert_select "turbo-frame#slug-status"
    assert_select "turbo-frame#slug-status span", count: 0
  end
end
