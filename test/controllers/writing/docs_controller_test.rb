require "test_helper"

class Writing::DocsControllerTest < ActionDispatch::IntegrationTest
  test "every door needs the writer" do
    doc = posts(:doc)

    get new_writing_doc_url
    assert_redirected_to new_session_url
    get edit_writing_doc_url(doc)
    assert_redirected_to new_session_url
    patch writing_doc_url(doc), params: { doc: { title: "Hijacked" } }
    assert_redirected_to new_session_url
    assert_equal "Teaching context", doc.reload.title
  end

  # The one promise the kind makes: nobody but the writer reads a doc, at any address.
  test "is not served at its slug, signed in or not" do
    doc = posts(:doc)

    get post_url(doc.slug, trailing_slash: true)
    assert_response :not_found

    sign_in_as users(:nityesh)
    get post_url(doc.slug, trailing_slash: true)
    assert_response :not_found
  end

  test "has no publishing route to be sent to" do
    sign_in_as users(:nityesh)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/writing/docs/#{posts(:doc).id}/publishing", method: :post)
    end
  end

  test "the editor is the post's canvas with a margin and nothing public on it" do
    sign_in_as users(:nityesh)
    doc = posts(:doc)

    get edit_writing_doc_url(doc)
    assert_response :success
    assert_select ".editor-shell.editor-shell--doc[data-controller~=comments]"
    assert_select "lexxy-editor"
    # Nothing to publish or preview, and no public URL to warn about.
    assert_select ".editor-bar__publish", count: 0
    assert_select ".publish-popover", count: 0
    assert_select "a", text: "Preview", count: 0
    assert_select "input[name='doc[feature_image]']", count: 0
    # Delete still has its form to submit.
    assert_select "form#delete-post[action=?]", writing_doc_path(doc)

    # The margin: open threads addressed by dom_id and carrying their pin, resolved ones folded.
    assert_select ".doc-rail turbo-frame#doc_comments" do
      assert_select "article##{dom_id(comments(:advisor))}[data-comments-target=thread][data-quote=?]", "Think like a PhD advisor"
      assert_select "article##{dom_id(comments(:advisor))} .comment", count: 2
      assert_select "details.doc-rail__resolved article##{dom_id(comments(:settled))}"
      assert_select "details.doc-rail__resolved article[data-comments-target]", count: 0
    end
    assert_select "form.comment-card--composer[hidden][action=?]", writing_doc_comments_path(doc)
  end

  test "a post's editor has no margin" do
    sign_in_as users(:nityesh)

    get edit_writing_post_url(posts(:draft))
    assert_select ".doc-rail", count: 0
    assert_select ".editor-shell--doc", count: 0
    assert_select ".editor-shell[data-controller~=comments]", count: 0
    assert_select ".editor-bar__publish"
  end

  test "autosave create mints one doc and brings its margin in" do
    sign_in_as users(:nityesh)

    assert_difference -> { Doc.count }, 1 do
      post writing_docs_url, headers: { "X-Autosave" => "true" },
        params: { doc: { title: "Launch plan", body: "<p>Step one.</p>" } }
    end
    doc = Doc.find_by!(title: "Launch plan")

    assert_response :created
    assert_equal edit_writing_doc_url(doc), response.headers["X-Edit-Url"]
    assert_select "turbo-stream[target=editor-margin] .doc-rail"
    assert_select "turbo-stream[target=editor-actions] .editor-bar__publish", count: 0
    assert_select "turbo-stream[target=editor-tag-mint]", count: 0
  end

  test "autosave create refuses to mint a blank doc" do
    sign_in_as users(:nityesh)

    assert_no_difference -> { Doc.count } do
      post writing_docs_url, headers: { "X-Autosave" => "true" }, params: { doc: { title: "", body: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "autosave saves the prose and hands back the new version" do
    sign_in_as users(:nityesh)
    doc = posts(:doc)

    patch writing_doc_url(doc), headers: { "X-Autosave" => "true" },
      params: { doc: { title: doc.title, body: "<p>Rewritten.</p>", lock_version: doc.lock_version } }

    assert_includes [ 200, 204 ], response.status
    assert_includes doc.reload.body.to_s, "Rewritten."
    assert_equal doc.lock_version.to_s, response.headers["X-Lock-Version"]
  end

  test "a retitle keeps the address" do
    sign_in_as users(:nityesh)
    doc = posts(:doc)
    address = edit_writing_doc_url(doc)

    patch writing_doc_url(doc), headers: { "X-Autosave" => "true" },
      params: { doc: { title: "A different name", lock_version: doc.lock_version } }

    assert_equal "A different name", doc.reload.title
    assert_equal address, edit_writing_doc_url(doc)
  end

  test "a save from a tab that fell behind is refused" do
    sign_in_as users(:nityesh)
    doc = posts(:doc)
    stale = doc.lock_version
    doc.update!(title: "Saved from the other tab")

    patch writing_doc_url(doc), headers: { "X-Autosave" => "true" },
      params: { doc: { title: "Saved from this one", lock_version: stale } }

    assert_response :conflict
    assert_equal "Saved from the other tab", doc.reload.title
  end

  test "can't be made public by a forged field" do
    sign_in_as users(:nityesh)
    doc = posts(:doc)

    patch writing_doc_url(doc), headers: { "X-Autosave" => "true" },
      params: { doc: { title: doc.title, status: "published", published_at: 1.day.ago, lock_version: doc.lock_version } }

    assert doc.reload.draft?
  end

  test "destroy deletes the doc" do
    sign_in_as users(:nityesh)

    assert_difference -> { Doc.count }, -1 do
      delete writing_doc_url(posts(:doc))
    end
    assert_redirected_to writing_root_url
  end

  test "the dashboard lists docs as private, with what's waiting in the margin" do
    sign_in_as users(:nityesh)

    get writing_root_url
    assert_select "button.dash-tab[data-status=doc]", text: /Docs\s+1/
    assert_select "a[href=?]", new_writing_doc_path, text: "New doc"
    assert_select "li.dash-row[data-status=doc]" do
      assert_select "a[href=?]", edit_writing_doc_path(posts(:doc))
      assert_select ".status", text: "Private"
      assert_select ".dash-row__when", text: "1 open comment"
      assert_select ".dash-row__url", count: 0
    end
  end
end
