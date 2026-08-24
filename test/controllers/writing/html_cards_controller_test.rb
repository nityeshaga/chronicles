require "test_helper"

class Writing::HtmlCardsControllerTest < ActionDispatch::IntegrationTest
  MARKUP = %(<div class="chart">drawn</div><script>draw()</script>)

  test "requires authentication" do
    post writing_html_cards_url, params: { content: MARKUP }
    assert_redirected_to new_session_url
  end

  test "keeps the markup and answers with an attachment that references it" do
    sign_in_as users(:nityesh)

    assert_difference -> { HtmlCard.count }, 1 do
      post writing_html_cards_url, params: { content: MARKUP }
    end

    assert_response :success
    assert_equal MARKUP, HtmlCard.last.content
    assert_includes response.body, HtmlCard.last.attachable_sgid
  end

  # What the editor previews is the static skeleton — the bytes stay in the record, which
  # is the whole reason the body carries a reference.
  test "the attachment carries the skeleton, not the script" do
    sign_in_as users(:nityesh)
    post writing_html_cards_url, params: { content: MARKUP }

    assert_includes response.body, "kg-html-card"
    assert_includes response.body, "drawn"
    assert_not_includes response.body, "draw()"
  end

  test "refuses a card with no markup" do
    sign_in_as users(:nityesh)

    assert_no_difference -> { HtmlCard.count } do
      post writing_html_cards_url, params: { content: "  " }
    end

    assert_response :unprocessable_entity
  end
end
