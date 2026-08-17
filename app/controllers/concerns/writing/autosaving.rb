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
    # rename); X-Edit-Url is the address the tab should now wear. The body is the Turbo
    # Stream that upgrades the open editor to its saved-post shape. Every URL is built by
    # polymorphic routing, so a page lands on the pages routes with no branch here.
    def render_mint(record)
      response.headers["X-Post-Id"] = record.id.to_s
      response.headers["X-Edit-Url"] = url_for([ :edit, :writing, record ])
      render template: "writing/posts/create", formats: :turbo_stream,
        status: :created, location: url_for([ :writing, record ])
    end
end
