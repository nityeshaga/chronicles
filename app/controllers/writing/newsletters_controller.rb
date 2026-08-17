class Writing::NewslettersController < Writing::BaseController
  before_action :set_post

  # Send the post to the list. The model refuses anything not live-and-unsent, so a
  # stale button or a double-submit can't double-send; either way we land back on the
  # editor with the popover already open, where the sent stamp is waiting.
  def create
    if @post.deliver_newsletter
      count = Subscriber.count
      redirect_to edit_writing_post_url(@post, publishing: "open"),
        notice: "Newsletter queued to #{count} #{"subscriber".pluralize(count)}."
    else
      redirect_to edit_writing_post_url(@post, publishing: "open"),
        alert: "This post can’t be sent — it must be published, not already mailed, and have someone to go to."
    end
  end

  private
    def set_post
      @post = Post.find_by!(slug: params[:post_id])
    end
end
