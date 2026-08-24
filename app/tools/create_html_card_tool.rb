# frozen_string_literal: true

class CreateHtmlCardTool < ActionTool::Base
  include HtmlIngestGate

  tool_name "create_html_card"
  description "Store a fragment of hand-authored markup — a bespoke table, a CSS grid, a chart that draws itself — and get back the attachment element that puts it in a post. A card is the one thing on this blog served to a reader unsanitized, so its bytes live in a record of their own and the body only ever carries the reference: splice the returned attachment_html into a body with update_post body_patches, then revise the card with update_html_card without touching the post again. Everywhere the script can't run — email, feeds, search descriptions, reading time — the card degrades to its markup with script and style pruned. A real <table> needs no card: tables are ordinary prose here and render natively in a mail client, which a card never will. The markup is screened on the way in and anything suspect comes back in warnings; nothing is refused."
  annotations(
    title: "Create HTML Card",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:html).filled(:string).description("The card's markup, stored and served byte-for-byte. Scope any <style> with @scope or a class prefix the card owns, or it restyles the whole article. Any <script> must be safe to run twice — draw by replacing a container's contents, never by appending — and should bind turbo:load, or a repeat visit or a back-button restore leaves the card blank. Absolute URLs for images; upload_image returns them.")
  end

  def call(html:)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    card = HtmlCard.new(content: html)

    if card.save
      {
        id: card.id,
        attachment_html: attachment_html(card),
        stored: describe_html_card(card.content),
        warnings: screen_html_card(card.content).presence,
        message: "Splice attachment_html into a body with update_post body_patches (the 'old' anchor must appear exactly once), or include it in the body on create_post. Change the markup later with update_html_card — every post carrying this card picks it up."
      }.compact
    else
      { error: card.errors.full_messages.join(", ") }
    end
  end

  private
    # The sgid and nothing else, which is the whole form the body ever holds — the same
    # element the editor inserts, so a card an agent wrote and a card a human wrote are
    # indistinguishable by the time they reach a post.
    def attachment_html(card)
      %(<action-text-attachment sgid="#{card.attachable_sgid}"></action-text-attachment>)
    end
end
