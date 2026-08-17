require "test_helper"

class Writing::PostsControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get writing_posts_url
    assert_redirected_to new_session_url
  end

  test "index lists drafts and published when signed in" do
    sign_in_as users(:nityesh)
    get writing_posts_url
    assert_response :success
  end

  # Account actions belong in the account menu, not a mis-click from the writing controls
  # — signing out mid-draft was one slipped click away when they shared a bar. The menu
  # now sits in the page's bottom-left corner, so the header holds none of it at all.
  test "the account menu holds the account actions, and the header holds none of them" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    assert_select ".writing-dash > details.dash-menu"
    assert_select ".dash-menu a[href=?]", root_path, text: "View site"
    assert_select ".dash-menu a[href=?]", writing_connect_path, text: "Connect"
    assert_select ".dash-menu form[action=?] input[name=_method][value=delete]", session_path
    assert_select ".dash-menu button", text: "Sign out"

    assert_select ".dash-head .dash-menu", count: 0
    assert_select ".dash-head__actions > a[href=?]", writing_connect_path, count: 0
    assert_select ".dash-head__actions > form[action=?]", session_path, count: 0
  end

  # Three "New …" controls became one: a post is a single click, its two rarer siblings
  # drop out of the caret instead of trailing the tab row.
  test "the New control keeps a post one click and hangs the other kinds off its caret" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    assert_select ".w-split a.w-btn--primary[href=?]", new_writing_post_path, text: /New post/
    assert_select ".w-split .w-menu a[href=?]", new_writing_page_path, text: "New page"
    assert_select ".w-split .w-menu a[href=?]", new_writing_html_page_path, text: "New HTML page"
    assert_select ".dash-tabs a", count: 0
  end

  # HTML pages are Pages by STI but are edited nowhere near the Lexxy form, so the
  # Pages bucket scopes to the exact type — a row here would link straight into the
  # editor that overwrites their stored document.
  test "the Pages bucket excludes HTML pages" do
    sign_in_as users(:nityesh)
    get writing_posts_url
    assert_response :success
    assert_select "a[href=?]", edit_writing_page_path(posts(:about))
    assert_select "a[href=?]", edit_writing_page_path(posts(:html_page)), count: 0
  end

  test "HTML pages get their own bucket linking into their own editor" do
    sign_in_as users(:nityesh)
    get writing_posts_url
    assert_response :success
    assert_select ".dash-tab[data-status=?]", "html_page"
    assert_select ".dash-row[data-status=?] a[href=?]", "html_page",
      edit_writing_html_page_path(posts(:html_page))
  end

  # --- The dashboard: one list, last touched first. ---

  # The tabs filter one rendered list, so the list has one sort — and what a writer
  # coming back is looking for is the thing he was last working on, whatever kind it is.
  test "the dashboard is one list ordered by what was touched last" do
    sign_in_as users(:nityesh)
    posts(:about).touch
    get writing_posts_url

    assert_equal Post.order(updated_at: :desc).map(&:title),
      css_select(".dash-row__title").map(&:text)
    assert_equal "About", css_select(".dash-row__title").first.text
  end

  # "Edited 23 Dec" reads identically in 2024 and 2025, and this stamp is the sort axis.
  test "every row prints the year it was edited and stamps the sort keys it is sorted by" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    Post.find_each do |record|
      assert_select ".dash-row[data-edited=?] .dash-row__date", record.updated_at.iso8601,
        text: "Edited #{record.updated_at.strftime("%-d %b %Y")}"
    end
  end

  # The go-live time is the Scheduled tab's sort axis, so the client reads it off the row
  # rather than parsing the sentence next to it.
  test "a scheduled row carries its go-live time as a sort key" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    scheduled = posts(:scheduled)
    assert_select ".dash-row[data-status=scheduled][data-goes-live=?]", scheduled.published_at.iso8601
    assert_select ".dash-row[data-status=draft][data-goes-live=?]", "", true
  end

  # Counts describe the buckets, so they are a tally of the one list on screen.
  test "tab counts tally the rendered list" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    assert_select ".dash-tab[data-status=all] .dash-tab__count", text: Post.count.to_s
    Post.all.group_by(&:dashboard_bucket).each do |bucket, records|
      assert_select ".dash-tab[data-status=?] .dash-tab__count", bucket, text: records.size.to_s
      assert_select ".dash-row[data-status=?]", bucket, count: records.size
    end
  end

  test "creates a post when signed in" do
    sign_in_as users(:nityesh)
    assert_difference -> { Post.articles.count }, 1 do
      post writing_posts_url, params: { post: { title: "Brand New", body: "<p>hi</p>" } }
    end
    assert_redirected_to edit_writing_post_url(Post.last)
  end

  # --- New-post autosave: the first real keystroke mints the draft server-side via a
  #     silent fetch (X-Autosave) so nothing is lost, then answers 201 with the edit URL
  #     in Location for the JS to adopt in place. Blank forms never mint a draft. ---
  test "autosave create mints exactly one draft and returns its edit URL" do
    sign_in_as users(:nityesh)
    assert_difference -> { Post.articles.count }, 1 do
      post writing_posts_url, headers: { "X-Autosave" => "true" },
        params: { post: { title: "Fresh Draft", body: "<p>opening line</p>" } }
    end
    assert_response :created
    # Location is the created resource — the exact URL the JS will PATCH, adopted verbatim.
    assert_equal writing_post_url(Post.last), response.location
    # The id rides alongside it: identity the editor can keep, unlike a slug.
    assert_equal Post.last.id.to_s, response.headers["X-Post-Id"]
    assert_equal "Fresh Draft", Post.last.title
  end

  test "autosave create refuses to mint a blank draft" do
    sign_in_as users(:nityesh)
    assert_no_difference -> { Post.count } do
      post writing_posts_url, headers: { "X-Autosave" => "true" }, params: { post: { title: "", body: "" } }
    end
    assert_response :unprocessable_entity
    assert_empty response.body
  end

  test "autosave create titles a body-first draft so it can persist" do
    sign_in_as users(:nityesh)
    assert_difference -> { Post.articles.count }, 1 do
      post writing_posts_url, headers: { "X-Autosave" => "true" },
        params: { post: { title: "", body: "<p>wrote the body before the title</p>" } }
    end
    assert_response :created
    assert_equal "Untitled", Post.last.title
  end

  test "two untitled drafts in a row both persist with distinct slugs" do
    sign_in_as users(:nityesh)
    assert_difference -> { Post.articles.count }, 2 do
      2.times do |i|
        post writing_posts_url, headers: { "X-Autosave" => "true" },
          params: { post: { title: "", body: "<p>body-first draft #{i}</p>" } }
        assert_response :created
      end
    end
    first, second = Post.articles.order(:id).last(2)
    assert_equal "untitled", first.slug
    assert_equal "untitled-2", second.slug
  end

  # --- Autosave contract: the debounced fetch (an X-Autosave header) is silent both
  #     ways — 204 on success, a bodyless 422 on failure — so nothing repaints. ---
  test "autosave persists changes and returns no content" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), headers: { "X-Autosave" => "true" },
      params: { post: { title: "Autosaved Title", body: "<p>edited</p>" } }
    assert_response :no_content
    assert_equal "Autosaved Title", draft.reload.title
  end

  # A blank title on a DRAFT is the body-first flow (the model re-fills the placeholder);
  # only a published post genuinely demands a title, so that's where 422 still lives.
  test "autosave answers a bodyless 422 on a validation failure so it never repaints" do
    sign_in_as users(:nityesh)
    published = posts(:published)
    patch writing_post_url(published), headers: { "X-Autosave" => "true" }, params: { post: { title: "" } }
    assert_response :unprocessable_entity
    assert_empty response.body
  end

  test "autosaving a body-first draft with a still-empty title keeps the placeholder and saves" do
    sign_in_as users(:nityesh)
    post writing_posts_url, headers: { "X-Autosave" => "true" },
      params: { post: { title: "", body: "<p>first line</p>" } }
    assert_response :created

    draft = Post.last
    patch writing_post_url(draft), headers: { "X-Autosave" => "true" },
      params: { post: { title: "", body: "<p>first line, and a second</p>" } }
    assert_response :no_content
    assert_equal "Untitled", draft.reload.title
    assert_includes draft.body.to_s, "and a second"
  end

  # --- Explicit save (no header, a normal Turbo submit): a slug change redirects once,
  #     and a validation failure re-renders the form with its errors. ---
  test "committing a changed slug redirects so the form URL stays live" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { slug: "renamed-draft" } }
    assert_redirected_to edit_writing_post_url(draft.reload)
    assert_equal "renamed-draft", draft.slug
  end

  test "an explicit save re-renders the form on a validation failure" do
    sign_in_as users(:nityesh)
    published = posts(:published)
    patch writing_post_url(published), params: { post: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "ul.errors"
  end

  # --- Feature image: an upload is adopted into the feature_image URL column so every
  #     existing renderer consumes it unchanged. ---
  test "uploading a feature image adopts its blob path into the feature_image column" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: {
      uploaded_feature_image: fixture_file_upload("feature.png", "image/png") } }
    assert draft.reload.uploaded_feature_image.attached?
    assert_match %r{/rails/active_storage/blobs/.+/feature\.png}, draft.feature_image
  end

  # --- Publishing resource: create = publish, destroy = unpublish/cancel. ---
  test "publishing a draft flips its status" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    post writing_post_publishing_url(draft)
    assert draft.reload.published?
    assert_redirected_to edit_writing_post_url(draft)
  end

  test "publishing with a future time schedules the post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    post writing_post_publishing_url(draft), params: { published_at: 2.days.from_now.iso8601 }
    assert draft.reload.draft?
    assert draft.scheduled?
  end

  test "unpublishing sends a post back to draft" do
    sign_in_as users(:nityesh)
    published = posts(:published)
    delete writing_post_publishing_url(published)
    assert published.reload.draft?
  end

  test "destroy removes the post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    assert_difference -> { Post.count }, -1 do
      delete writing_post_url(draft)
    end
    # 303: the browser arrives on a real DELETE fetch, and a 302 would make it replay
    # DELETE against the redirect target.
    assert_redirected_to writing_root_url
    assert_response :see_other
  end

  test "the editor's forms are all siblings — never nested" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:draft))

    # The browser's HTML parser drops a <form> opened inside another form, which once
    # turned the Delete button into a submit button of the edit form (a silent PATCH
    # instead of a DELETE). assert_select can't see this — its HTML5 parser performs
    # the same stripping — so pin the raw markup: form tags must strictly alternate.
    response.body.scan(/<form[\s>]|<\/form>/).each_slice(2) do |pair|
      assert_match(/\A<form[\s>]\z/, pair.first, "found a <form> nested inside another form")
      assert_equal "</form>", pair.last
    end

    # And the delete button reaches its sibling form by the HTML form attribute.
    assert_select "button[form=delete-post]", text: "Delete post"
    assert_select "form#delete-post input[name=_method][value=delete]"
  end

  # The slug field's availability line: an empty frame the slug controller aims at the
  # slugs endpoint as the writer types.
  test "the editor carries the slug-status frame" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:draft))
    assert_select "turbo-frame#slug-status[data-slug-target=status]"
    assert_select "input[name=?][data-slug-target=slug]", "post[slug]"
  end

  test "preview renders the public post template behind auth" do
    sign_in_as users(:nityesh)
    get writing_post_url(posts(:draft))
    assert_response :success
    assert_select "article.gh-article"
  end
end
