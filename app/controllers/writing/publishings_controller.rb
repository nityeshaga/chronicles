class Writing::PublishingsController < Writing::BaseController
  before_action :set_post

  # The model answers false and says why, so a refusal comes back as the editor with the
  # reason sitting under the field that caused it rather than a silent bounce off the
  # same button. It travels as its own flash: the publish popover renders it, and the
  # form's general problem list must not print it a second time.
  def create
    flash[:publish_error] = @post.errors.full_messages.to_sentence unless @post.publish(at: params[:published_at])
    redirect_to editor_url
  end

  def destroy
    @post.unpublish
    redirect_to editor_url
  end

  private
    # Nested under posts, pages and HTML pages; the resource is found by slug whichever
    # parent it arrived under, and the redirect is polymorphic so it lands back on the
    # right editor.
    def set_post
      @post = Post.find_by!(slug: params[:post_id] || params[:page_id] || params[:html_page_id])
    end

    # Back to the editor with the publish popover already open. The writer asked a
    # publishing question a second ago; the answer — LIVE, SCHEDULED, or the refusal —
    # belongs on screen, not behind a click he has to know to make.
    def editor_url
      edit_polymorphic_url([ :writing, @post ], publishing: ("open" if @post.publish_popover?))
    end
end
