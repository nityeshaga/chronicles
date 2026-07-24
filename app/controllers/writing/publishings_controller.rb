class Writing::PublishingsController < Writing::BaseController
  before_action :set_post

  def create
    @post.publish(at: params[:published_at])
    redirect_to [ :edit, :writing, @post ]
  end

  def destroy
    @post.unpublish
    redirect_to [ :edit, :writing, @post ]
  end

  private
    # Nested under both posts and pages; the resource is found by slug either way, and
    # the redirect is polymorphic so it lands back on the right editor.
    def set_post
      @post = Post.find_by!(slug: params[:post_id] || params[:page_id])
    end
end
