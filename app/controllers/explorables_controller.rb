class ExplorablesController < ApplicationController
  allow_unauthenticated_access
  # Rails refuses to answer a plain GET with JavaScript (anti-JSONP-hijack) unless told the
  # script is meant to be loaded from a page. These are: a bundle's own engine.js, public
  # bytes with no session behind them.
  skip_forgery_protection

  # A companion file of an explorable, at its authored path. The front door (/slug/) is
  # PostsController#show like every other page — this answers everything under it.
  # Binary because that's what was uploaded: no layout, no meta, no template — the bytes
  # and the type they were saved with, ETagged so a reload of a big deck is a 304.
  def show
    explorable = Explorable.viewable(writer: signed_in?).find_by!(slug: params[:slug])
    asset = explorable.asset_at(params[:path]) or raise ActiveRecord::RecordNotFound
    fresh_when asset
    return if performed?

    send_data asset.content, type: asset.content_type, disposition: :inline
  end
end
