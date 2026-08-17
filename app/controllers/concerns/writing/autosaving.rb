# The editor's save contract, shared by the two controllers that answer it. Posts and
# pages are written on the same autosaving form, so they owe the client the same three
# answers — and when each spelled them out for itself they drifted: a failed page mint
# used to render a whole form down a wire the client reads as silence.
module Writing::Autosaving
  extend ActiveSupport::Concern

  private
    def autosave_request?
      request.headers["X-Autosave"].present?
    end

    # A record is only worth minting once the author has typed something; keeps blank
    # drafts from piling up if the create endpoint is hit with an empty form.
    def draft_content?(attributes)
      attributes[:title].present? || attributes[:body].present?
    end

    # The mint's answer. Location is the created resource — the PATCH target the JS
    # adopts verbatim; X-Post-Id is identity a slug can't give (it goes stale on the next
    # rename). The body is the Turbo Stream that upgrades the open editor to its
    # saved-post shape.
    def render_mint(record)
      response.headers["X-Post-Id"] = record.id.to_s
      slug_headers(record)
      render template: "writing/posts/create", formats: :turbo_stream,
        status: :created, location: url_for([ :writing, record ])
    end

    # The silent answer to a debounced save: bare, unless the save moved the record's
    # slug. Then it carries the same headers the mint does, because the same addresses
    # move — and the client re-points itself with them instead of reloading, which is the
    # whole reason the URL can live on the canvas.
    def render_autosave(record, renamed:)
      return head :no_content unless renamed

      slug_headers(record)
      head :no_content, location: url_for([ :writing, record ])
    end

    # Everything the open editor is holding that has the slug baked into it: the address
    # the tab should wear, the view button's href, and the slug the record actually kept
    # (asked for "hello" on a collision, a new record keeps "hello-2"). Built by
    # polymorphic routing, so a page lands on the pages routes with no branch here, and
    # handed over whole — the client never assembles a URL out of a slug.
    def slug_headers(record)
      response.headers["X-Slug"] = record.slug
      response.headers["X-Edit-Url"] = url_for([ :edit, :writing, record ])
      response.headers["X-View-Url"] =
        record.published? ? helpers.public_post_url(record) : url_for([ :writing, record ])
    end
end
