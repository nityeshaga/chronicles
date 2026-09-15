# frozen_string_literal: true

class CreateShipTool < ActionTool::Base
  include ShipToolSupport

  tool_name "create_ship"
  description "Log a new ship as a DRAFT — one thing shipped on a day. Publishing is a separate step (publish_ship) and is what mints its No. number. Attach a preview with upload_ship_media. Link `post` when the ship announces something on this site (its URL then defaults to the post's)."
  annotations(
    title: "Create Ship",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:title).filled(:string).description("One line, the way it reads in the log: 'Luo can take a phone call now.'")
    required(:kind).filled(:string).description("One of: #{Ship.kinds.keys.join(", ")}.")
    required(:built_by).filled(:string).description("'nityesh', 'luo' or 'together'.")
    optional(:shipped_on).filled(:string).description("The day it shipped, ISO date (YYYY-MM-DD). Defaults to today.")
    optional(:blurb).filled(:string).description("Two or three sentences under the title.")
    optional(:check_it_out_url).filled(:string).description("Door 1: where 'Check it out' goes. Omit when `post` is set and the post is the destination.")
    optional(:prompt).filled(:string).description("Door 2: the prompt a reader copies into their own agent. Omit for no button.")
    optional(:post).filled.description("Id or slug of the post / HTML page / explorable this ship announces.")
    optional(:how_built_post).filled.description("Door 3: id or slug of the 'How I built this' post. Omit while unwritten.")
    optional(:x_status_id).filled(:string).description("The X post's status id (the digits at the end of its URL).")
  end

  def call(title:, kind:, built_by:, shipped_on: nil, blurb: nil, check_it_out_url: nil, prompt: nil, post: nil, how_built_post: nil, x_status_id: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    linked, error = resolve_post_link(post, "post")
    return error if error
    how_built, error = resolve_post_link(how_built_post, "how_built_post")
    return error if error

    ship = Ship.new(
      title: title,
      kind: kind,
      built_by: built_by,
      shipped_on: shipped_on.presence || Date.current,
      blurb: blurb,
      check_it_out_url: check_it_out_url,
      prompt: prompt,
      post: linked,
      how_built_post: how_built,
      x_status_id: x_status_id
    )

    if ship.save
      serialize(ship).merge(message: "Draft logged. Add media with upload_ship_media, revise with update_ship, then publish_ship to give it a number and put it in the log.")
    else
      { error: ship.errors.full_messages.to_sentence }
    end
  end
end
