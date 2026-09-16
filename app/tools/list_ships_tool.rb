# frozen_string_literal: true

class ListShipsTool < ActionTool::Base
  include ShipToolSupport

  DEFAULT_LIMIT = 50
  MAX_LIMIT = 200

  tool_name "list_ships"
  description "List the ship log — everything shipped, newest first — with optional status and kind filters. A ship is one thing shipped on a day (app, skill, explorable, comic, chronicle) with its blurb, media, and doors. Returns every field; there is no separate get."
  annotations(
    title: "List Ships",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    optional(:status).filled(:string).description("'draft' or 'published'. Omit for both.")
    optional(:kind).filled(:string).description("One of: #{Ship.kinds.keys.join(", ")}.")
    optional(:limit).filled(:integer).description("Max results (default: #{DEFAULT_LIMIT}, max: #{MAX_LIMIT}).")
  end

  def call(status: nil, kind: nil, limit: DEFAULT_LIMIT)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user
    return { error: "status must be 'draft' or 'published'." } if status.present? && !Ship.statuses.key?(status)
    return { error: "kind must be one of: #{Ship.kinds.keys.join(", ")}." } if kind.present? && !Ship.kinds.key?(kind)

    scope = Ship.ordered
    scope = scope.where(status: status) if status.present?
    scope = scope.where(kind: kind) if kind.present?

    { ships: scope.limit(limit.clamp(1, MAX_LIMIT)).map { |ship| serialize(ship) }, total_count: scope.count }
  end
end
