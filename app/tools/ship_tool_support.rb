# frozen_string_literal: true

module ShipToolSupport
  include PostToolSupport

  private
    def resolve_ship(id)
      Ship.find_by(id: id)
    end

    # The two post links arrive as an id or a slug, the way every post tool takes them.
    # Returns [post, nil] or [nil, error] so the caller can bail with the tool's own message.
    def resolve_post_link(reference, field)
      return [ nil, nil ] if reference.blank?

      post = resolve_post(reference)
      post ? [ post, nil ] : [ nil, { error: "#{field} '#{reference}' not found. Use list_posts to find the right id or slug." } ]
    end

    def serialize(ship)
      {
        id: ship.id,
        number: ship.number,
        status: ship.status,
        shipped_on: ship.shipped_on.iso8601,
        kind: ship.kind,
        title: ship.title,
        blurb: ship.blurb,
        built_by: ship.built_by,
        check_it_out_url: ship.check_it_out_url,
        prompt: ship.prompt,
        post: ship.post&.slug,
        how_built_post: ship.how_built_post&.slug,
        x_status_id: ship.x_status_id,
        media_kind: ship.media_kind,
        preview_url: ship.preview_url,
        poster_url: ship.poster_url,
        published_at: ship.published_at&.iso8601
      }.compact
    end
end
