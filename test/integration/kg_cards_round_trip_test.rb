require "test_helper"

# One of every Ghost card the archive holds (test/fixtures/files/kg_cards.html, lifted from
# real posts). The editor reads each as a node — an image node for a plain image card, an
# opaque content attachment for the rest — and writes the node back; this proves the server
# half of that contract: the public page is the same page either way, and the body the
# editor writes is the body it reads next time.
class KgCardsRoundTripTest < ActionDispatch::IntegrationTest
  include ActionView::Helpers::TagHelper

  MARKERS = %w[<iframe kg-image-card kg-gallery-card kg-embed-card kg-bookmark-card kg-toggle-card
               kg-callout-card kg-button-card <figcaption twitter-tweet srcset=].freeze

  setup do
    sign_in_as users(:nityesh)
    @draft = posts(:draft)
    @cards = Nokogiri::HTML5.fragment(file_fixture("kg_cards.html").read).children.select(&:element?)
  end

  # What lexxy_kg_cards.js makes of each card on load, exported the way Lexxy exports it.
  def as_the_editor_saves(card)
    if card.matches?("figure.kg-image-card") && card.at_css("img[srcset]").nil?
      img, caption = card.at_css("img"), card.at_css("figcaption")
      tag.send("action-text-attachment", "", url: img["src"], alt: img["alt"], caption: caption&.inner_html,
        "content-type": "image/*", filename: img["src"].split("/").last, presentation: "gallery")
    else
      tag.send("action-text-attachment", "", "content-type": "text/html", content: card.to_html)
    end.then { |attachment| "<p>#{attachment}</p>" }
  end

  def public_page_for(body)
    patch writing_post_url(@draft), params: { post: { body: } }
    post writing_post_publishing_url(@draft) unless @draft.reload.published?
    get post_url(@draft)
    follow_redirect!
    response.body[/<section class="gh-content-wrapper.*?<\/section>/m]
  end

  def counts(html) = MARKERS.to_h { |marker| [ marker, html.scan(marker).size ] }

  def editor_value
    get edit_writing_post_url(@draft)
    Nokogiri::HTML5.fragment(response.body).at_css("lexxy-editor")["value"]
  end

  def save_as_the_editor_would(value)
    body = ActionText::Fragment.wrap(value).replace("action-text-attachment[content]") do |node|
      node["content"] = JSON.parse(node["content"])
      node
    end.to_html
    patch writing_post_url(@draft), params: { post: { body: } }
  end

  test "the public page is the same page before and after the editor has held it" do
    imported = public_page_for(@cards.map(&:to_html).join)
    edited = public_page_for(@cards.map { |card| as_the_editor_saves(card) }.join)

    assert_equal counts(imported), counts(edited)
    assert_equal Nokogiri::HTML5.fragment(imported).text.squish, Nokogiri::HTML5.fragment(edited).text.squish
    assert_select "figure.kg-image-card", @cards.count { |c| c.matches?("figure.kg-image-card") }
    assert_select ".attachment--content", false
  end

  test "the stored body is the same body save after save" do
    patch writing_post_url(@draft), params: { post: { body: @cards.map { |card| as_the_editor_saves(card) }.join } }
    first = @draft.reload.body.body.to_html

    value = editor_value
    save_as_the_editor_would(value)
    assert_equal first, @draft.reload.body.body.to_html
    assert_equal value, editor_value
  end
end
