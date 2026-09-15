# frozen_string_literal: true

class PublishShipTool < ActionTool::Base
  include ShipToolSupport

  tool_name "publish_ship"
  description "Put a drafted ship in the log. Mints its № number (the next in sequence) the first time; re-publishing keeps it."
  annotations(
    title: "Publish Ship",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:id).filled(:integer).description("The ship's id, from list_ships or create_ship.")
  end

  def call(id:)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    ship = resolve_ship(id)
    return ToolErrors::SHIP_NOT_FOUND unless ship

    ship.publish
    serialize(ship).merge(message: "Published as № #{format("%03d", ship.number)}.")
  rescue ActiveRecord::RecordInvalid => e
    { error: e.record.errors.full_messages.to_sentence }
  end
end
