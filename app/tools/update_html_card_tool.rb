# frozen_string_literal: true

class UpdateHtmlCardTool < ActionTool::Base
  include HtmlIngestGate

  tool_name "update_html_card"
  description "Replace an HTML card's markup, identified by the id create_html_card returned. The bytes live in the card's own record, so every post attaching it serves the new markup and no body is rewritten — this is why editing a chart never means resending a post. The markup is screened the same way and comes back in warnings; nothing is refused."
  annotations(
    title: "Update HTML Card",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:id).filled.description("The card's numeric id, as returned by create_html_card.")
    required(:html).filled(:string).description("The card's new markup, replacing the old wholesale. Same rules: <style> scoped with @scope or a class prefix, <script> safe to run twice and bound to turbo:load, absolute URLs for images.")
  end

  def call(id:, html:)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    card = HtmlCard.find_by(id: id)
    return ToolErrors::HTML_CARD_NOT_FOUND unless card

    if card.update(content: html)
      {
        id: card.id,
        stored: describe_html_card(card.content),
        warnings: screen_html_card(card.content).presence,
        message: "Card updated. Every post attaching it now serves the new markup."
      }.compact
    else
      { error: card.errors.full_messages.join(", ") }
    end
  end
end
