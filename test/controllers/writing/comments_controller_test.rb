require "test_helper"

class Writing::CommentsControllerTest < ActionDispatch::IntegrationTest
  setup { @doc = posts(:doc) }

  test "the margin needs the writer" do
    get writing_doc_comments_url(@doc)
    assert_redirected_to new_session_url

    assert_no_difference -> { Comment.count } do
      post writing_doc_comments_url(@doc), params: { comment: { body: "Drive-by." } }
    end
    assert_redirected_to new_session_url
  end

  test "index is the frame and nothing else" do
    sign_in_as users(:nityesh)

    get writing_doc_comments_url(@doc)
    assert_response :success
    assert_no_match(/<html|<body/, response.body)
    assert_select "turbo-frame#doc_comments article.comment-card", count: 2
  end

  test "a comment is pinned to the passage it was left on and signed by the writer" do
    sign_in_as users(:nityesh)

    assert_difference -> { @doc.comments.threads.count }, 1 do
      post writing_doc_comments_url(@doc),
        params: { comment: { body: "Which three?", quote: "next three tutorials", prefix: "Show the " } }
    end
    assert_redirected_to writing_doc_comments_url(@doc)

    comment = @doc.comments.threads.ordered.last
    assert_equal "Which three?", comment.body
    assert_equal "next three tutorials", comment.quote
    assert_equal "Show the ", comment.prefix
    assert_equal "Nityesh Agarwal", comment.author_name
  end

  test "a reply lands in its thread" do
    sign_in_as users(:nityesh)

    assert_difference -> { comments(:advisor).replies.count }, 1 do
      post writing_doc_comments_url(@doc), params: { comment: { body: "Do that.", parent_id: comments(:advisor).id } }
    end
    follow_redirect!
    assert_select "article##{dom_id(comments(:advisor))} .comment", count: 3
  end

  test "a blank comment is refused" do
    sign_in_as users(:nityesh)

    assert_no_difference -> { Comment.count } do
      post writing_doc_comments_url(@doc), params: { comment: { body: " " } }
    end
    assert_response :unprocessable_entity
  end

  test "a comment can't be signed as someone else" do
    sign_in_as users(:nityesh)

    post writing_doc_comments_url(@doc), params: { comment: { body: "Hello.", author_name: "Somebody Else" } }
    assert_equal "Nityesh Agarwal", @doc.comments.ordered.last.author_name
  end

  test "deleting a reply leaves the thread; deleting the thread takes its replies" do
    sign_in_as users(:nityesh)

    assert_difference -> { Comment.count }, -1 do
      delete writing_doc_comment_url(@doc, comments(:advisor_reply))
    end
    assert_redirected_to writing_doc_comments_url(@doc)
    assert Comment.exists?(comments(:advisor).id)

    Comment.create!(parent: comments(:advisor), author_name: "Luo", body: "One more.")
    assert_difference -> { Comment.count }, -2 do
      delete writing_doc_comment_url(@doc, comments(:advisor))
    end
  end

  test "a comment is only reachable through its own doc" do
    sign_in_as users(:nityesh)
    other = Doc.create!(title: "Another doc")

    delete writing_doc_comment_url(other, comments(:advisor))
    assert_response :not_found
    assert Comment.exists?(comments(:advisor).id)
  end

  test "a post has no margin to comment in" do
    sign_in_as users(:nityesh)

    post writing_doc_comments_url(posts(:draft).id), params: { comment: { body: "Hello." } }
    assert_response :not_found
  end
end
