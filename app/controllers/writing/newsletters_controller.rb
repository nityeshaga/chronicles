class Writing::NewslettersController < Writing::BaseController
  before_action :set_post

  # Send the post to the list. The model refuses anything not live-and-unsent, so a
  # stale button or a double-submit can't double-send; either way we land back on the
  # editor, where the publish popover now shows the sent state.
  def create
    if @post.deliver_newsletter
      count = Subscriber.count
      redirect_to [ :edit, :writing, @post ],
        notice: "Newsletter queued to #{count} #{"subscriber".pluralize(count)}."
    else
      redirect_to [ :edit, :writing, @post ],
        alert: "This post can’t be sent — it must be published, not already mailed, and have someone to go to."
    end
  end

  private
    def set_post
      @post = Post.find_by!(slug: params[:post_id])
    end
end
