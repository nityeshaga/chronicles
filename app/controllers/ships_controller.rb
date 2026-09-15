class ShipsController < ApplicationController
  allow_unauthenticated_access

  # The homepage: everything shipped, newest first, under month headers.
  def index
    @ships = Ship.log.with_attached_preview.with_attached_poster.includes(:post, :how_built_post)
    @months = @ships.group_by { |ship| ship.shipped_on.beginning_of_month }
    # A signup redirect carries a one-time flash; skip conditional-GET so a cached
    # ETag can't 304 the confirmation/error away before it's seen. The machines
    # digest is in the ETag because the "apps running" count comes from that file.
    fresh_when etag: [ @ships, Machine.cache_key ], last_modified: @ships.maximum(:updated_at) unless flash.any?
  end
end
