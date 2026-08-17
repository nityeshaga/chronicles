# The editor's save contract, shared by the two controllers that answer it. Posts and
# pages are written on the same autosaving form, so they owe the client the same answers
# — and when each spelled them out for itself they drifted: a failed page mint used to
# render a whole form down a wire the client reads as silence.
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

    # Two ways in, one action, and both editors answer it identically because they answer
    # the same form. Every save here is the editor's (Post#save_keeping_url), so neither
    # path is ever refused over a URL. The silent fetch stays silent — a bodyless 422 on a
    # real failure, so a bad keystroke can't repaint the page mid-sentence — while an
    # explicit Turbo submit (the feature-image file, the only field left off the silent
    # path) can't read a header, so a rename it made is announced the one way a browser
    # will follow: a single redirect to the new edit URL.
    #
    # No slug in the request is the editor saying the URL is still the title's to invent.
    # Absence, not a blank value: a writer who empties the field has typed a name the post
    # can't have, which is a refusal, not a rename.
    def update_from_editor(record, attributes)
      derive = !attributes.key?(:slug) && !record.addressed?

      if record.save_keeping_url(attributes, derive_slug: derive)
        renamed = record.saved_change_to_slug?
        adopt_feature_image_upload(record)

        if !renamed
          head :no_content
        elsif autosave_request?
          render_editor_chrome(record, status: :ok)
        else
          redirect_to [ :edit, :writing, record ]
        end
      elsif autosave_request?
        head :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def render_mint(record)
      render_editor_chrome(record, status: :created)
    end

    # The mint's answer, and a rename's — one renderer, because a rename installs exactly
    # what the mint did. Everything hanging off a saved post addresses it by slug: the
    # publish form, the delete form, the tag mint, the untitled note's URL. Re-stamping
    # them from their one home is what keeps a renamed draft's Publish button from posting
    # to a URL that stopped existing two keystrokes ago.
    #
    # Location is the created (or renamed) resource — the PATCH target the JS adopts
    # verbatim; X-Edit-Url is the address the tab should now wear; X-Slug is the slug the
    # record actually kept, which is the only slug the canvas may show; X-Post-Id is
    # identity a slug can't give (it goes stale on the next rename). Every URL is built by
    # polymorphic routing, so a page lands on the pages routes with no branch here.
    def render_editor_chrome(record, status:)
      response.headers["X-Post-Id"] = record.id.to_s
      response.headers["X-Slug"] = record.slug
      response.headers["X-Edit-Url"] = url_for([ :edit, :writing, record ])
      render template: "writing/posts/create", formats: :turbo_stream,
        status: status, location: url_for([ :writing, record ]), locals: { post: record }
    end
end
