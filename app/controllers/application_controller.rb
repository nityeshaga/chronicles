class ApplicationController < ActionController::Base
  include Authentication

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Site identity (masthead, footer, meta/OG/JSON-LD, RSS channel) is read from
  # Setting on every page, but the fresh_when ETags are computed from posts/tags
  # only. Fold the row into every conditional GET so editing it invalidates any
  # client's cached copy.
  etag { Setting.current }

  # Public pages grow writer-only chrome (dashboard nav, edit pill) once signed
  # in; without this, a browser holding the anonymous copy would 304 it away.
  etag { signed_in? }

  # The masthead orders the shelves by whichever kind shipped last, on every page. A
  # shelf's own ETag only knows its own kind, so the order rides in here too: publishing
  # a comic must reorder the nav on a cached /apps/. One query per request, shared with
  # the layout.
  etag { kinds_by_recency }

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # Ghost served every URL with a trailing slash and 301'd the bare form; match it
  # so inbound links don't double-redirect and canonicals stay stable.
  before_action :redirect_to_trailing_slash

  # The canonical public host lives in Setting; everything else — the sslip.io
  # preview, an IP, a staging alias — gets noindexed so it can't be indexed as
  # duplicate content. Derived from the request, so it self-heals the moment DNS
  # points the production host here.
  after_action :discourage_indexing_off_production

  private
    def render_not_found
      render "shared/not_found", status: :not_found, formats: :html
    end

    def discourage_indexing_off_production
      response.set_header("X-Robots-Tag", "noindex") unless request.host == Setting.current.production_host
    end

    # The path as the browser sent it. Rack strips the trailing slash from PATH_INFO;
    # ORIGINAL_FULLPATH keeps it — and the slash is canonical here, so anything that
    # names a page (a red-pen note, the slash redirect) reads this, not request.path.
    def requested_path
      (request.env["ORIGINAL_FULLPATH"] || request.fullpath).split("?", 2).first
    end
    helper_method :requested_path

    def kinds_by_recency
      @kinds_by_recency ||= Ship.kinds_by_recency
    end
    helper_method :kinds_by_recency

    def redirect_to_trailing_slash
      return unless request.get? || request.head?
      raw_path = requested_path
      return if raw_path == "/" || raw_path.end_with?("/") || File.extname(raw_path).present?

      path = request.path
      return if path.start_with?("/up", "/rails", "/assets", "/writing", "/session", "/oauth", "/.well-known")

      query = request.query_string.presence
      redirect_to "#{path}/#{"?#{query}" if query}", status: :moved_permanently
    end
end
