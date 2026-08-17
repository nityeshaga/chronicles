class Writing::PublishingsController < Writing::BaseController
  before_action :set_post

  # The model answers false and says why, so a refusal comes back as the editor with the
  # reason on it rather than a silent bounce off the same button.
  def create
    @post.publish(at: params[:published_at])
    redirect_to [ :edit, :writing, @post ], alert: @post.errors.full_messages.to_sentence.presence
  end

  def destroy
    @post.unpublish
    redirect_to [ :edit, :writing, @post ]
  end

  private
    # Nested under posts, pages and HTML pages; the resource is found by slug whichever
    # parent it arrived under, and the redirect is polymorphic so it lands back on the
    # right editor.
    def set_post
      @post = Post.find_by!(slug: params[:post_id] || params[:page_id] || params[:html_page_id])
    end
end
