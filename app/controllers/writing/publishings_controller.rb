class Writing::PublishingsController < Writing::BaseController
  before_action :set_post

  # The model answers false and says why, so a refusal comes back as the editor with the
  # reason inside the popover rather than a silent bounce off the same button.
  def create
    flash[:publish_error] = @post.errors.full_messages.to_sentence unless @post.publish(at: params[:published_at])
    redirect_to_editor
  end

  def destroy
    @post.unpublish
    redirect_to_editor
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
    # belongs on screen, not behind a click he has to know to make. The HTML-page editor
    # has no popover to open and ignores the flash.
    def redirect_to_editor
      flash[:publishing] = "open"
      redirect_to edit_polymorphic_url([ :writing, @post ])
    end
end
