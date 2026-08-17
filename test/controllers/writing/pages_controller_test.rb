require "test_helper"

class Writing::PagesControllerTest < ActionDispatch::IntegrationTest
  test "new requires authentication" do
    get new_writing_page_url
    assert_redirected_to new_session_url
  end

  test "creates a page when signed in" do
    sign_in_as users(:nityesh)
    assert_difference -> { Page.count }, 1 do
      post writing_pages_url, params: { page: { title: "Colophon", body: "<p>hi</p>" } }
    end
    page = Page.find_by!(slug: "colophon")
    assert_redirected_to edit_writing_page_url(page)
  end

  # A page is written on the same autosaving form as a post, so it can arrive here as a
  # silent fetch. Answering with a redirect made the client read a dead session and mint
  # the page again on the next keystroke.
  test "autosave create mints exactly one page and returns its PATCH URL" do
    sign_in_as users(:nityesh)
    assert_difference -> { Page.count }, 1 do
      post writing_pages_url, headers: { "X-Autosave" => "true" },
        params: { page: { title: "Colophon", body: "<p>hi</p>" } }
    end
    page = Page.find_by!(slug: "colophon")

    assert_response :created
    assert_equal writing_page_url(page), response.location
    assert_equal page.id.to_s, response.headers["X-Post-Id"]
  end

  test "autosave create refuses to mint a blank page" do
    sign_in_as users(:nityesh)
    assert_no_difference -> { Page.count } do
      post writing_pages_url, headers: { "X-Autosave" => "true" }, params: { page: { title: "", body: "" } }
    end
    assert_response :unprocessable_entity
    assert_empty response.body
  end

  # The silent path is silent on failure too — a rendered form here reads as a redirect
  # to the client, i.e. a dead session, while the record simply failed to validate.
  test "a failed autosave create stays bodyless" do
    sign_in_as users(:nityesh)
    posts(:about).update_column(:slug, "taken-twice")

    post writing_pages_url, headers: { "X-Autosave" => "true" },
      params: { page: { title: "Taken Twice", body: "<p>hi</p>", slug: "taken-twice" } }

    assert_response :unprocessable_entity
    assert_empty response.body
  end

  # --- Pages share the autosave contract with posts: the debounced fetch is silent
  #     both ways, an explicit slug change redirects once. ---
  test "autosave persists changes and returns no content" do
    sign_in_as users(:nityesh)
    page = posts(:about)
    patch writing_page_url(page), headers: { "X-Autosave" => "true" },
      params: { page: { title: "About Me", body: "<p>edited</p>" } }
    assert_response :no_content
    assert_equal "About Me", page.reload.title
  end

  test "autosave answers a bodyless 422 on a validation failure" do
    sign_in_as users(:nityesh)
    page = posts(:about)
    patch writing_page_url(page), headers: { "X-Autosave" => "true" }, params: { page: { title: "" } }
    assert_response :unprocessable_entity
    assert_empty response.body
  end

  test "committing a changed slug redirects so the form URL stays live" do
    sign_in_as users(:nityesh)
    page = posts(:about)
    patch writing_page_url(page), params: { page: { slug: "about-me" } }
    assert_redirected_to edit_writing_page_url(page.reload)
    assert_equal "about-me", page.slug
  end

  test "publishing resource is nested under pages" do
    sign_in_as users(:nityesh)
    page = posts(:about)
    delete writing_page_publishing_url(page)
    assert page.reload.draft?
    assert_redirected_to edit_writing_page_url(page)
  end

  test "destroy removes the page" do
    sign_in_as users(:nityesh)
    page = posts(:about)
    assert_difference -> { Post.count }, -1 do
      delete writing_page_url(page)
    end
    assert_redirected_to writing_root_url
  end

  # The Lexxy form writes an Action Text body; loading an HTML page into it would
  # overwrite the stored document on the first save. It must not resolve at all.
  test "an HTML page slug cannot be opened through the pages editor" do
    sign_in_as users(:nityesh)
    get edit_writing_page_url(posts(:html_page))
    assert_response :not_found
  end

  test "preview renders the public post template behind auth" do
    sign_in_as users(:nityesh)
    get writing_page_url(posts(:about))
    assert_response :success
    assert_select "article.gh-article"
  end
end
