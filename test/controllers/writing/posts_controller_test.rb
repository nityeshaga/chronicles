require "test_helper"

class Writing::PostsControllerTest < ActionDispatch::IntegrationTest
  # The zone strings and stamp shape are the helper's, not this deployment's: a fork in
  # another zone should stay green on an app that is behaving.
  include Writing::PublishingHelper

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

    assert_equal Post.order(updated_at: :desc, id: :desc).map { |record| "/#{record.slug}/" },
      css_select(".dash-row__url").map(&:text)
    assert_equal "/about/", css_select(".dash-row__url").first.text
  end

  # Ties are the normal case, not the corner: the Ghost import stamped updated_at across
  # every row it wrote in one pass. Flatten the stamps and the only thing left to order by
  # is which row is newer — without the id tiebreaker SQLite hands them back oldest first.
  test "posts sharing an updated_at come back newest first, not in whatever order the DB likes" do
    sign_in_as users(:nityesh)
    Post.update_all(updated_at: 1.year.ago)
    get writing_posts_url

    assert_equal Post.order(id: :desc).map { |record| "/#{record.slug}/" },
      css_select(".dash-row__url").map(&:text)
  end

  # "Edited 23 Dec" reads identically in 2024 and 2025, and this stamp is the sort axis.
  test "every row prints the year it was edited and stamps the sort keys it is sorted by" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    Post.find_each do |record|
      assert_select ".dash-row[data-edited=?] .dash-row__date", record.updated_at.utc.iso8601,
        text: "Edited #{record.updated_at.strftime("%-d %b %Y")}"
    end
  end

  # The go-live time is the Scheduled tab's sort axis, so the client reads it off the row
  # rather than parsing the sentence next to it.
  test "a scheduled row carries its go-live time as a sort key and says it in the app's zone" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    scheduled = posts(:scheduled)
    assert_select ".dash-row[data-status=scheduled][data-goes-live=?]", scheduled.published_at.utc.iso8601
    assert_select ".dash-row__when",
      text: "· Goes live #{zoned_stamp(scheduled.published_at)}"
    assert_select ".dash-row[data-status=draft][data-goes-live=?]", "", true
  end

  test "a published row shows its URL and the date it went live" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    published = posts(:published)
    assert_select ".dash-row[data-status=published] .dash-row__url", text: "/#{published.slug}/"
    assert_select ".dash-row__when", text: "· Published #{published.published_at.strftime("%-d %b %Y")}"
  end

  # What the writer types is a title, a URL fragment or a tag; the row has to answer to
  # all three, lowercased, because the filter never touches the server.
  test "each row carries its title, slug and tag names for the filter to match" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    search = css_select(".dash-row[data-status=published]").first["data-search"]
    assert_includes search, "a published post"
    assert_includes search, "a-published-post"
    assert_includes search, "chronicles"
  end

  test "the filter box names what it matches" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    assert_select ".dash-filter input[type=search][placeholder=?]", "Filter by title, slug or tag"
  end

  # The axis a tab reads down rides on the tab, so the JS sorts what it is told to and
  # never has to know that "scheduled" is the one that reads forward in time.
  test "each tab carries the axis it sorts by, and Scheduled is the one that differs" do
    sign_in_as users(:nityesh)
    get writing_posts_url

    assert_select ".dash-tab[data-status=all][data-sort=edited][data-direction='-1'][aria-pressed=true]"
    assert_select ".dash-tab[data-status=published][data-sort=edited][data-direction='-1']"
    assert_select ".dash-tab[data-status=scheduled][data-sort='goes-live'][data-direction='1']"
    assert_select ".dash-tab[aria-pressed=true]", count: 1
    assert_select ".dash-tab[role=tab]", count: 0
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
    # And the address the tab should adopt, so a refresh reopens the draft.
    assert_equal edit_writing_post_url(Post.last), response.headers["X-Edit-Url"]
    assert_equal "Fresh Draft", Post.last.title
  end

  # The mint is also what turns the open canvas into a saved-post editor: without a
  # reload, Publish and everything else that needs a record has to arrive in the answer.
  test "the mint answers with the chrome only a saved post can carry" do
    sign_in_as users(:nityesh)
    post writing_posts_url, headers: { "X-Autosave" => "true" },
      params: { post: { title: "Fresh Draft", body: "<p>opening line</p>" } }
    minted = Post.last

    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[target=editor-actions]" do
      assert_select "a[href=?]", writing_post_path(minted), text: "Preview"
      assert_select "button.editor-bar__publish", text: /Publish/
    end
    assert_select "turbo-stream[target=editor-overlays] .publish-popover"
    assert_select "turbo-stream[target=editor-delete] button[form=delete-post]"
    assert_select "turbo-stream[target=editor-tag-mint] #new-tag-mint"
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

  # --- Publishing resource: create = publish, destroy = unpublish/cancel. Every one of
  #     them lands back on the editor with the popover open, so the state the writer just
  #     asked for is what he reads next. ---
  test "publishing a draft flips its status" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    post writing_post_publishing_url(draft)
    assert draft.reload.published?
    assert_redirected_to edit_writing_post_url(draft)
    assert_equal "open", flash[:publishing]
  end

  test "publishing with a future time schedules the post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    post writing_post_publishing_url(draft), params: { published_at: 2.days.from_now.iso8601 }
    assert draft.reload.draft?
    assert draft.scheduled?
    assert_redirected_to edit_writing_post_url(draft)
  end

  # The mistake this exists for: typing this morning's time this afternoon. Publishing on
  # the spot is not what was asked and not something an unpublish takes back, so it is
  # refused and said so — in the popover, which the redirect reopens.
  test "publishing at a time that has already passed is refused and says why" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    post writing_post_publishing_url(draft), params: { published_at: 1.hour.ago.iso8601 }

    assert draft.reload.draft?
    assert_nil draft.published_at
    assert_redirected_to edit_writing_post_url(draft)
    assert_equal "That time has already passed — pick a later one, or clear it to publish now.", flash[:publish_error]

    follow_redirect!
    assert_select ".publish-popover .publish-note--refused", text: /That time has already passed/
    assert_select ".editor-shell[data-editor-open-publish-value=true]"
  end

  # A refusal can land on a post that is already live or already scheduled — the popover
  # shows a state, not a form, and the reason has to survive that. One line, one place,
  # whichever of the three the post is in.
  test "a refusal reaches the popover on a scheduled post too" do
    sign_in_as users(:nityesh)
    scheduled = posts(:scheduled)

    post writing_post_publishing_url(scheduled), params: { published_at: 1.hour.ago.iso8601 }
    follow_redirect!
    assert_select ".publish-popover .status--scheduled"
    assert_select ".publish-popover .publish-note--refused", text: /That time has already passed/
  end

  test "unpublishing sends a post back to draft" do
    sign_in_as users(:nityesh)
    published = posts(:published)
    delete writing_post_publishing_url(published)
    assert published.reload.draft?
    assert_redirected_to edit_writing_post_url(published)
  end

  # The field names its zone and refuses the past before the round trip, and the button
  # says which of the two things it does — the labels ride in as data because the swap
  # happens in the browser as the field is filled.
  test "the publish form names its zone, floors the field at now, and carries both labels" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:draft))

    assert_select "form.schedule-form[data-label-swap-empty-value=Publish][data-label-swap-filled-value=Schedule]"
    assert_select "label[for=published_at]", text: "Publish time (#{publish_zone_label}) — leave blank to go live now"
    assert_select "input[type=datetime-local][name=published_at][min=?]", publish_time_floor
    assert_select "input[type=submit][data-label-swap-target=submit][value=Publish]"
  end

  # A time with no zone on it is a guess the writer has to make at the moment it matters.
  test "the popover stamps every publish time with the zone" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:scheduled))
    assert_select ".publish-state", text: "Scheduled Goes live #{zoned_stamp(posts(:scheduled).published_at)}."

    get edit_writing_post_url(posts(:published))
    assert_select ".publish-state", text: "Live Published #{zoned_stamp(posts(:published).published_at)}."
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

  # --- The URL: on the canvas, under the subtitle, where it is decided — with the
  #     availability frame the slug controller aims at the slugs endpoint beside it. ---
  test "the canvas carries the URL line: the host, the slug field, and its status frame" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:draft))

    assert_select ".editor-canvas .url-line" do
      assert_select ".url-line__host", text: "#{Setting.current.production_host}/"
      assert_select "input[name=?][data-slug-target=slug][data-autosave-target=slug]", "post[slug]"
      assert_select "turbo-frame#slug-status[data-slug-target=status]"
    end
  end

  # The panel is settings, and the URL is not one of them any more — nor is the excerpt,
  # which has been the subtitle on the canvas all along.
  test "the settings panel holds neither the URL nor a note about the subtitle" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:draft))

    assert_select ".settings-panel input[name=?]", "post[slug]", count: 0
    assert_select ".settings-panel", text: /Excerpt \/ subtitle/, count: 0
  end

  # A URL that is already out in the world is a different thing to edit, so the line says
  # so — but only when the writer is in it, which is when it matters.
  test "a live URL warns what changing it costs, and a draft's does not" do
    sign_in_as users(:nityesh)

    get edit_writing_post_url(posts(:published))
    assert_select ".url-line__hint", text: "Live URL — changing it breaks links people already have."

    get edit_writing_post_url(posts(:scheduled))
    assert_select ".url-line__hint", count: 1

    get edit_writing_post_url(posts(:draft))
    assert_select ".url-line__hint", count: 0
  end

  # --- The slug rides autosave, so a rename is silent too — and hands back every address
  #     that moved with it, since the editor is holding all of them. ---
  test "an autosaved rename answers 204 with the addresses it moved" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), headers: { "X-Autosave" => "true" },
      params: { post: { slug: "renamed-by-autosave" } }

    assert_response :no_content
    assert_equal "renamed-by-autosave", draft.reload.slug
    assert_equal writing_post_url(draft), response.location
    assert_equal draft.slug, response.headers["X-Slug"]
    assert_equal edit_writing_post_url(draft), response.headers["X-Edit-Url"]
    assert_equal writing_post_url(draft), response.headers["X-View-Url"]
  end

  # On a live post the view button points at the public page, so that is the href the
  # rename has to hand back.
  test "a renamed live post hands back its public URL for the view button" do
    sign_in_as users(:nityesh)
    published = posts(:published)
    patch writing_post_url(published), headers: { "X-Autosave" => "true" },
      params: { post: { slug: "renamed-while-live" } }

    assert_response :no_content
    assert_equal post_url(published.reload, trailing_slash: true), response.headers["X-View-Url"]
  end

  # Nothing moved, nothing to adopt: the ordinary keystroke save stays a bare 204.
  test "an autosave that leaves the slug alone carries no addresses" do
    sign_in_as users(:nityesh)
    patch writing_post_url(posts(:draft)), headers: { "X-Autosave" => "true" },
      params: { post: { title: "Still A Draft Post" } }

    assert_response :no_content
    assert_nil response.headers["X-Slug"]
    assert_nil response.location
  end

  # A slug another post holds is refused by the uniqueness validation, and that refusal
  # is an ordinary autosave failure: bodyless, so nothing repaints mid-keystroke. The
  # record keeps the URL it had; the availability frame under the field says why.
  test "an autosaved slug that is taken changes nothing and stays silent" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), headers: { "X-Autosave" => "true" },
      params: { post: { slug: posts(:published).slug, title: "Renamed Too" } }

    assert_response :unprocessable_entity
    assert_empty response.body
    assert_equal "a-draft-post", draft.reload.slug
    assert_equal "A Draft Post", draft.title
  end

  # The mint invents the slug (the client withholds it precisely so it can), and a title
  # someone already used comes back suffixed — so the answer has to say which slug the
  # record ended up with, or the canvas would show a URL the site doesn't serve.
  test "the mint hands back the slug it actually kept" do
    sign_in_as users(:nityesh)
    post writing_posts_url, headers: { "X-Autosave" => "true" },
      params: { post: { title: posts(:published).title, body: "<p>same name, new post</p>" } }

    assert_response :created
    assert_equal "a-published-post-2", Post.last.slug
    assert_equal Post.last.slug, response.headers["X-Slug"]
    assert_equal edit_writing_post_url(Post.last), response.headers["X-Edit-Url"]
  end

  # Mailing the list is irreversible, so the send is never one click: the confirm is the
  # second deliberate act. With nobody subscribed there is nothing to send, so the button
  # is absent rather than sitting there ready to be refused.
  test "the newsletter button confirms before it sends" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:published))
    assert_select ".publish-newsletter [data-turbo-confirm]", text: "Send as newsletter"
  end

  test "with nobody subscribed there is no newsletter button, and a line saying why" do
    Subscriber.delete_all
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:published))
    assert_select ".publish-newsletter form", count: 0
    assert_select ".publish-newsletter", text: /No subscribers yet — nothing to send\./
    assert_select ".publish-newsletter a[href=?]", writing_subscribers_path, text: "subscribers"
  end

  # --- The editor bar: no manual save, one view control, and a status line that opens
  #     with the truth instead of waiting for a keystroke to say anything. ---
  test "a new post carries no save button and nothing to publish" do
    sign_in_as users(:nityesh)
    get new_writing_post_url

    assert_select "input[type=submit]", count: 0
    assert_select ".editor-bar__publish", count: 0
    assert_select "#editor-actions"
    assert_select ".publish-popover", count: 0
  end

  test "the view control says Preview on a draft and View live once it's published" do
    sign_in_as users(:nityesh)

    get edit_writing_post_url(posts(:draft))
    assert_select ".editor-bar a[href=?]", writing_post_path(posts(:draft)), text: "Preview"

    get edit_writing_post_url(posts(:published))
    assert_select ".editor-bar a[href=?]", post_path(posts(:published), trailing_slash: true), text: "View live"
    # One control per meaning: the popover no longer carries its own copy.
    assert_select ".publish-popover a", text: "View live", count: 0
  end

  test "the status line opens saying where the post stands, in the bar and in the panel" do
    sign_in_as users(:nityesh)

    get edit_writing_post_url(posts(:draft))
    assert_select ".autosave-status[data-state=saved]", text: "Saved", count: 2

    get edit_writing_post_url(posts(:scheduled))
    assert_select ".autosave-status[data-state=saved]", text: "Saved · scheduled", count: 2

    # A live post says what the next save costs before a key is pressed.
    get edit_writing_post_url(posts(:published))
    assert_select ".autosave-status[data-state=live]", text: "Live · saves go public", count: 2
  end

  # The saved-state copy is Ruby's, handed to the client as a finished sentence rather
  # than a rule for building one.
  test "the form hands the editor the sentence to print once a save lands" do
    sign_in_as users(:nityesh)

    get edit_writing_post_url(posts(:published))
    assert_select "form[data-autosave-saved-text-value=?]", "Saved · live"

    get edit_writing_post_url(posts(:draft))
    assert_select "form[data-autosave-saved-text-value=Saved]"
  end

  # --- The untitled guard: the placeholder title is the model letting body-first
  #     writing persist, not a title. It can't reach the public site. ---
  test "an untitled draft shows the empty title field, not the placeholder word" do
    sign_in_as users(:nityesh)
    untitled = Post.create!(body: "<p>body first</p>")

    get edit_writing_post_url(untitled)
    assert_equal "Untitled", untitled.title
    assert_select "textarea.editor-canvas__title", text: ""
  end

  test "the popover refuses to publish an untitled draft and says where it would land" do
    sign_in_as users(:nityesh)
    untitled = Post.create!(body: "<p>body first</p>")

    get edit_writing_post_url(untitled)
    assert_select ".publish-note",
      text: /Give it a title first — right now it would go live at #{Setting.current.production_host}\/untitled\//
    assert_select ".schedule-form input[type=submit][disabled]"

    # And the server refuses it too — the stale-tab path, where the button was rendered
    # before the title was cleared. The reason lands in the popover the redirect reopens,
    # which is the only place the writer is looking after clicking Publish.
    post writing_post_publishing_url(untitled)
    assert untitled.reload.draft?
    assert_nil untitled.published_at
    follow_redirect!
    assert_select ".publish-note--refused", text: /is still the placeholder/
  end

  test "a titled draft's popover publishes without a note" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:draft))

    assert_select ".publish-note[hidden]"
    assert_select ".schedule-form input[type=submit][disabled]", count: 0
  end

  # Pasting a link is the only way to embed one, so the empty body is the only place a
  # writer learns embeds exist. The controller listens on the body, where the paste lands.
  test "the editor teaches embeds through the body placeholder" do
    sign_in_as users(:nityesh)
    get new_writing_post_url

    assert_select ".editor-canvas__body[data-controller=embed][data-action=?]",
      "lexxy:insert-link->embed#unfurl"
    assert_select "lexxy-editor[placeholder=?]",
      "Start writing. Paste a tweet or YouTube link on its own line to embed it."
  end

  test "preview renders the public post template behind auth" do
    sign_in_as users(:nityesh)
    get writing_post_url(posts(:draft))
    assert_response :success
    assert_select "article.gh-article"
  end
end
