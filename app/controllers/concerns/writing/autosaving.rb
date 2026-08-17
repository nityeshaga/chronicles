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
    # the same form. The silent fetch saves the editor's way — never refused over a URL —
    # and stays silent either way: a bodyless 422 on a real failure, so a bad keystroke
    # can't repaint the page mid-sentence.
    def update_from_editor(record, attributes)
      if autosave_request?
        record.autosave(editor_attributes(record, attributes)) ? render_saved(record) : head(:unprocessable_entity)
      elsif record.update(attributes)
        # An explicit Turbo submit (the feature-image file, the only field left off the
        # silent path) can't read a header, so a rename it made is announced the one way a
        # browser will follow: a single redirect to the new edit URL.
        renamed = record.saved_change_to_slug?
        adopt_feature_image_upload(record)
        renamed ? redirect_to([ :edit, :writing, record ]) : head(:no_content)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # What the editor sent, as the model reads it. A slug arrives only once the writer has
    # taken the field over; while it still follows the title the URL is the model's to
    # invent, and a blank slug is how you ask for that. An addressed post is the exception
    # — its URL is a promise to whoever holds the link, and only a hand edit breaks one.
    def editor_attributes(record, attributes)
      return attributes if attributes.key?(:slug) || record.addressed?

      attributes.merge(slug: nil)
    end

    # 204 for an ordinary keystroke: nothing repaints and the cursor never jumps. A save
    # that moved the slug answers with the chrome instead, because that chrome is now wrong.
    def render_saved(record)
      renamed = record.saved_change_to_slug?
      adopt_feature_image_upload(record)
      renamed ? render_editor_chrome(record, status: :ok) : head(:no_content)
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
        status: status, location: url_for([ :writing, record ])
    end
end
