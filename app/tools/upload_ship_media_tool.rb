# frozen_string_literal: true

class UploadShipMediaTool < ActionTool::Base
  include MediaFetching
  include ShipToolSupport

  # What each slot accepts, as Content-Type prefixes. A preview is a muted looping mp4 or
  # a still; a poster is the frame a video shows before it plays, so always an image.
  SLOTS = {
    "preview" => { types: %w[ video/mp4 image/ ], expected: "an mp4 video or an image" },
    "poster" => { types: %w[ image/ ], expected: "an image" }
  }.freeze

  tool_name "upload_ship_media"
  description "Fetch an mp4, jpg or png from a public http(s) URL and attach it to a ship as its preview (the media in its log entry) or poster (the first frame shown before a video preview plays). Replaces whatever the slot held. The server does the fetching so bytes never pass through this call. Keep previews short and small: a 10–15 second muted 720px loop, tens of KB to a few hundred, not the full video."
  annotations(
    title: "Upload Ship Media",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: true
  )

  arguments do
    required(:id).filled(:integer).description("The ship's id.")
    required(:source_url).filled(:string).description("Public http:// or https:// URL of the file to fetch.")
    optional(:slot).filled(:string).description("'preview' (default) or 'poster'.")
    optional(:filename).filled(:string).description("Filename to store the blob under. Derived from the URL or content type when omitted.")
  end

  def call(id:, source_url:, slot: "preview", filename: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    ship = resolve_ship(id)
    return ToolErrors::SHIP_NOT_FOUND unless ship

    accepts = SLOTS[slot]
    return { error: "slot must be 'preview' or 'poster'." } unless accepts

    fetched = fetch_remote_file(source_url, types: accepts[:types], max_bytes: MAX_VIDEO_BYTES, expected: accepts[:expected])
    return fetched if fetched.is_a?(Hash)

    ship.public_send(slot).attach(
      io: StringIO.new(fetched.bytes),
      filename: filename_for(source_url, fetched.content_type, filename),
      content_type: fetched.content_type
    )

    {
      id: ship.id,
      slot: slot,
      content_type: fetched.content_type,
      byte_size: fetched.bytes.bytesize,
      media_kind: ship.media_kind,
      url: ship.public_send("#{slot}_url"),
      message: slot == "preview" && ship.media_kind == :video ? "Attached. A video preview wants a poster too: call again with slot 'poster' and a jpg of its first frame." : "Attached."
    }
  end
end
