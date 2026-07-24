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

  test "preview renders the public post template behind auth" do
    sign_in_as users(:nityesh)
    get writing_page_url(posts(:about))
    assert_response :success
    assert_select "article.gh-article"
  end
end
