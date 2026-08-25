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

  # The canvas frames a card by asking for this: the bytes, in the published typography,
  # with none of the page around them — and a sandbox the document asserts of itself, so
  # a card's script can't reach the writer's session from inside the editor or from a tab.
  test "show serves one card bare, sandboxed, behind auth" do
    card = HtmlCard.create!(content: MARKUP)

    get writing_html_card_url(card.attachable_sgid)
    assert_redirected_to new_session_url

    sign_in_as users(:nityesh)
    get writing_html_card_url(card.attachable_sgid)
    assert_response :success
    assert_includes response.body, MARKUP
    assert_select "body.html-card .kg-html-card .chart", "drawn"
    assert_select ".gh-viewport", count: 0
    assert_no_match "writing-app", response.body
    assert_equal "sandbox allow-scripts; frame-ancestors 'self'", response.headers["Content-Security-Policy"]
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
  end

  # The id is a signature, not a number: a foreign record's sgid and a made-up string are
  # both nothing, and so is a card that was since deleted.
  test "show answers anything but a card's own signature with 404" do
    sign_in_as users(:nityesh)

    get writing_html_card_url(posts(:draft).to_sgid(for: "attachable").to_param)
    assert_response :not_found

    get writing_html_card_url("not-a-signature")
    assert_response :not_found

    card = HtmlCard.create!(content: MARKUP)
    card.destroy
    get writing_html_card_url(card.attachable_sgid)
    assert_response :not_found
  end

  test "refuses a card with no markup" do
    sign_in_as users(:nityesh)

    assert_no_difference -> { HtmlCard.count } do
      post writing_html_cards_url, params: { content: "  " }
    end

    assert_response :unprocessable_entity
  end
end
