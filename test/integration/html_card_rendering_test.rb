require "test_helper"

# End-to-end proof that an HTML card survives the whole trip: the body attaches the record
# by sgid, the public post serves its bytes raw, and every medium that can't run one —
# email, feed, plain text, search description — gets the static skeleton instead of a
# chart's source code.
class HtmlCardRenderingTest < ActionDispatch::IntegrationTest
  MARKUP = %(<style>.chart td { padding: 7px }</style>) +
           %(<div class="chart"><table><tr><td>drawn</td></tr></table></div>) +
           %(<script>document.querySelector(".chart").dataset.ran = "yes";</script>)

  setup { @card = HtmlCard.create!(content: MARKUP) }

  # The body Lexxy submits for an inserted card: an attachment carrying the record's sgid
  # and nothing else. The bytes never travel in the document.
  def editor_card(card = @card)
    %(<action-text-attachment sgid="#{card.attachable_sgid}"></action-text-attachment>)
  end

  def publish_with_card(card = @card)
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: editor_card(card) } }
    post writing_post_publishing_url(draft)
    draft.reload
  end

  test "a card's script and style reach the public post verbatim" do
    published = publish_with_card

    get post_url(published)
    follow_redirect!
    assert_response :success

    assert_includes response.body, %(<style>.chart td { padding: 7px }</style>)
    assert_includes response.body, %(<script>document.querySelector(".chart").dataset.ran = "yes";</script>)
    assert_select "div.kg-card.kg-html-card .chart td", "drawn"
  end

  test "the public post serves a card's bytes once" do
    publish_with_card

    get post_url(posts(:draft).reload)
    follow_redirect!
    assert_equal 1, response.body.scan("document.querySelector").size
  end

  # The shape the editor stores: Lexxy inserts a card inline, so Lexical parents it into a
  # paragraph. An HTML parser will not keep a <div> inside a <p>, so the card's static
  # skeleton gets hoisted out of the attachment on the way to the page — which showed the
  # card twice, once expanded and once static, on every post written in the editor.
  test "a card the editor parented into a paragraph renders once" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: "<p>#{editor_card}</p>" } }
    post writing_post_publishing_url(draft)

    get post_url(draft.reload)
    follow_redirect!
    assert_select "div.kg-html-card", 1
    assert_select "div.kg-html-card--static", false, "the static skeleton must not survive alongside the card"
  end

  # The writer previews before publishing, and a preview that can't run the card is a
  # preview of something else.
  test "a card renders in the writer's preview" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: editor_card } }

    get writing_post_url(draft.reload)
    assert_response :success
    assert_select "div.kg-html-card .chart td", "drawn"
  end

  # The reference is the whole body, so a save can't corrupt the bytes and a 267KB chart
  # never rides an autosave.
  test "the stored body carries a reference, not the markup" do
    publish_with_card
    stored = posts(:draft).reload.body.body.to_html

    assert_includes stored, @card.attachable_sgid
    assert_not_includes stored, "querySelector"
  end

  # The size of the reference is the size of the reference, whatever the card weighs. This
  # is the reason the bytes live in a record: the real article's chart card is 267KB, and
  # it would otherwise ride every autosave and sit in every stored revision.
  test "a heavy card does not weigh on the body" do
    heavy = HtmlCard.create!(content: "<script>#{'x' * 100_000}</script>")
    publish_with_card(heavy)

    assert_operator posts(:draft).reload.body.body.to_html.length, :<, 500
  end

  test "re-saving what the editor exports leaves the reference intact" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: editor_card } }
    patch writing_post_url(draft), params: { post: { body: editor_card } }

    assert_equal [ @card ], draft.reload.body.body.attachables
  end

  # Opening the editor is where a card reference is most fragile: Lexxy re-renders every
  # attachment server-side on the way in, and asks each one for a content type it doesn't
  # have to have. A card written by an agent — sgid and nothing else — is the shape that
  # found this, and it 500'd the whole page.
  test "the editor opens on a post carrying an agent-written card" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: editor_card } }

    get edit_writing_post_url(draft.reload)
    assert_response :success
    assert_includes response.body, @card.attachable_sgid
  end

  # Rails' sanitizer strips a <script> tag but keeps the JavaScript inside it as text. The
  # attachment partial renders the pruned form, so nothing downstream has to remember that.
  test "a card's script is not prose" do
    published = publish_with_card

    assert_not_includes published.summary, "querySelector"
    assert_includes published.summary, "drawn"

    get post_url(published)
    follow_redirect!
    assert_select ".gh-article-meta-length", /1 min read/
  end

  test "the newsletter sends the static card and says what it lost" do
    published = publish_with_card
    mail = NewsletterMailer.issue(published, subscribers(:reader))

    assert_not_includes mail.html_part.decoded, "querySelector"
    assert_not_includes mail.text_part.decoded, "querySelector"
    assert_includes mail.html_part.decoded, "drawn"
    assert_match(/only run in a browser/, mail.html_part.decoded)
  end

  test "a card without a script raises no note in the newsletter" do
    published = publish_with_card(HtmlCard.create!(content: %(<div class="chart">static</div>)))

    assert_no_match(/only run in a browser/, NewsletterMailer.issue(published, subscribers(:reader)).html_part.decoded)
  end

  test "the feed carries the static card" do
    publish_with_card

    get "/rss/"
    assert_response :success
    assert_not_includes response.body, "querySelector"
    assert_includes response.body, "drawn"
  end

  # The post partial caches its rendered body on [post, post.html_cards, Setting.current].
  # The cards have to be in that key because the post's own timestamp can't speak for them:
  # update_html_card revises a card without touching any post carrying it, and every one of
  # those posts would go on serving the bytes it cached. (Asserted on the key's ingredients
  # rather than through a request — the suite runs on a null store, so a request-level
  # version of this test passes whether the key is right or wrong.)
  test "a post's cache key follows the cards it carries" do
    published = publish_with_card
    assert_equal [ @card ], published.html_cards

    before = published.html_cards.map(&:cache_key_with_version)
    @card.update!(content: %(<div class="chart">redrawn</div>))

    assert_not_equal before, published.reload.html_cards.map(&:cache_key_with_version)
  end

  # A card whose record is gone must not take the post down with it.
  test "a deleted card leaves the post standing" do
    published = publish_with_card
    @card.destroy

    get post_url(published)
    follow_redirect!
    assert_response :success
    assert_select "div.kg-html-card", false
  end

  # Tables are prose now, not something a card has to carry: they render in a mail client,
  # which is the whole reason they're allow-listed rather than left to cards.
  test "a bare table renders on the public post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    patch writing_post_url(draft), params: { post: { body: "<table><tbody><tr><td>9.5</td></tr></tbody></table>" } }
    post writing_post_publishing_url(draft)

    get post_url(draft.reload)
    follow_redirect!
    assert_select "table td", "9.5"
  end

  # Embeds are attachments too, and they are not cards: their provider script is loaded by
  # the tweets controller, and serving both would run it twice.
  test "an embed is not a card" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    inner = Embed.new("https://twitter.com/nityeshaga/status/999").to_html
    patch writing_post_url(draft), params: { post: {
      body: %(<action-text-attachment content-type="text/html" content="#{ERB::Util.html_escape(inner)}"></action-text-attachment>)
    } }
    post writing_post_publishing_url(draft)

    get post_url(draft.reload)
    follow_redirect!
    assert_select "blockquote.twitter-tweet"
    assert_select "div.kg-html-card", false, "an embed must not render as a card"
    assert_no_match(/platform\.twitter\.com\/widgets\.js/, response.body)
  end
end
