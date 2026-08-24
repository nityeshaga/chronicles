class Writing::HtmlCardsController < Writing::BaseController
  # Paste markup → get back the attachment element that stands for it in the body. The
  # bytes are the writer's own, but the reference can only be minted here: an sgid is this
  # app's signature over a record that doesn't exist until the writer presses Insert.
  #
  # The response is the same element Lexxy exports for a card it already carries — sgid,
  # and the static skeleton in `content` for the editor to preview — so an inserted card
  # and a reloaded one are the same thing to everything downstream.
  def create
    card = HtmlCard.new(content: params[:content])

    if card.save
      render html: attachment_for(card)
    else
      render plain: "A card needs markup", status: :unprocessable_entity
    end
  end

  private
    def attachment_for(card)
      ActionText::Attachment.from_attachable(card, content: render_to_string(partial: card).chomp).to_html.html_safe
    end
end
