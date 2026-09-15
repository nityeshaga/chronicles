# frozen_string_literal: true

class UpdateShipTool < ActionTool::Base
  include ShipToolSupport

  tool_name "update_ship"
  description "Update a ship's fields. Only the fields you pass change. Media is attached with upload_ship_media, not here."
  annotations(
    title: "Update Ship",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:id).filled(:integer).description("The ship's id, from list_ships or create_ship.")
    optional(:title).filled(:string).description("New title.")
    optional(:kind).filled(:string).description("One of: #{Ship.kinds.keys.join(", ")}.")
    optional(:built_by).filled(:string).description("'nityesh', 'luo' or 'together'.")
    optional(:shipped_on).filled(:string).description("ISO date (YYYY-MM-DD).")
    optional(:blurb).filled(:string).description("New blurb.")
    optional(:check_it_out_url).filled(:string).description("New 'Check it out' URL.")
    optional(:prompt).filled(:string).description("New copyable prompt.")
    optional(:post).filled.description("Id or slug of the post this ship announces.")
    optional(:how_built_post).filled.description("Id or slug of the 'How I built this' post.")
    optional(:x_status_id).filled(:string).description("The X post's status id.")
  end

  def call(id:, title: nil, kind: nil, built_by: nil, shipped_on: nil, blurb: nil, check_it_out_url: nil, prompt: nil, post: nil, how_built_post: nil, x_status_id: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    ship = resolve_ship(id)
    return ToolErrors::SHIP_NOT_FOUND unless ship

    linked, error = resolve_post_link(post, "post")
    return error if error
    how_built, error = resolve_post_link(how_built_post, "how_built_post")
    return error if error

    attributes = {
      title: title, kind: kind, built_by: built_by, shipped_on: shipped_on, blurb: blurb,
      check_it_out_url: check_it_out_url, prompt: prompt, x_status_id: x_status_id,
      post: linked, how_built_post: how_built
    }.compact

    if ship.update(attributes)
      serialize(ship).merge(changed: attributes.keys)
    else
      { error: ship.errors.full_messages.to_sentence }
    end
  end
end
