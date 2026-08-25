class Writing::HtmlCardsController < Writing::BaseController
  # The framed card is the author's own markup running on this origin, behind his own
  # sign-in — the same trust HtmlPage already extends. The sandbox is for the one place
  # that trust isn't the point: the writer's canvas, where a card's script has no business
  # reading the session or the post around it. The frame asks for `sandbox="allow-scripts"`
  # and the document asserts the same, so opening the URL in a tab changes nothing.
  content_security_policy only: :show do |policy|
    policy.sandbox "allow-scripts"
    policy.frame_ancestors :self
  end

  # Paste markup → get back the attachment element that stands for it in the body. The
  # bytes are the writer's own, but the reference can only be minted here: an sgid is this
  # app's signature over a record that doesn't exist until the writer presses Insert.
  #
  # The response is the same element Lexxy exports for a card it already carries — sgid,
  # and the static skeleton in `content` for everything that can't run a card — so an
  # inserted card and a reloaded one are the same thing to everything downstream.
  def create
    card = HtmlCard.new(content: params[:content])

    if card.save
      render html: attachment_for(card)
    else
      render plain: "A card needs markup", status: :unprocessable_entity
    end
  end

  # One card, bare, for the canvas to frame. Found by the sgid the attachment carries —
  # the same signature HtmlCard.expand resolves — so the URL the canvas fills in is a
  # reference it was already holding, and an unsigned or foreign id is nothing.
  def show
    @card = ActionText::Attachable.from_attachable_sgid(params[:id], only: HtmlCard)
    render layout: false
  end

  private
    def attachment_for(card)
      ActionText::Attachment.from_attachable(card, content: render_to_string(partial: card).chomp).to_html.html_safe
    end
end
