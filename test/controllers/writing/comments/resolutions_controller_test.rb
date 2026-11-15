require "test_helper"

class Writing::Comments::ResolutionsControllerTest < ActionDispatch::IntegrationTest
  setup { @doc = posts(:doc) }

  test "needs the writer" do
    post writing_doc_comment_resolution_url(@doc, comments(:advisor))
    assert_redirected_to new_session_url
    assert_not comments(:advisor).reload.resolved?
  end

  test "resolving folds the thread away, replies and all" do
    sign_in_as users(:nityesh)

    post writing_doc_comment_resolution_url(@doc, comments(:advisor))
    assert_redirected_to writing_doc_comments_url(@doc)
    assert comments(:advisor).reload.resolved?

    follow_redirect!
    assert_select "article[data-comments-target=thread]", count: 0
    assert_select "details.doc-rail__resolved article.comment-card", count: 2
    assert_select "details.doc-rail__resolved summary", text: "2 resolved threads"
  end

  test "reopening brings it back beside the prose" do
    sign_in_as users(:nityesh)

    delete writing_doc_comment_resolution_url(@doc, comments(:settled))
    assert_not comments(:settled).reload.resolved?

    follow_redirect!
    assert_select "article##{dom_id(comments(:settled))}[data-comments-target=thread]"
    assert_select "details.doc-rail__resolved", count: 0
  end

  test "only a thread can be resolved, not a reply" do
    sign_in_as users(:nityesh)

    post writing_doc_comment_resolution_url(@doc, comments(:advisor_reply))
    assert_response :not_found
  end
end
