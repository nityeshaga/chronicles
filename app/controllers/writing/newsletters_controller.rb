class Writing::NewslettersController < Writing::BaseController
  before_action :set_post

  # Send the post to the list. The model refuses anything not live-and-unsent, so a
  # stale button or a double-submit can't double-send; either way we land back on the
  # editor with the popover already open, showing the sent stamp or the refusal. The
  # refusal travels as publish_error like every other one: the popover is the only thing
  # the writer can see with the backdrop up.
  def create
    if @post.deliver_newsletter
      count = Subscriber.count
      flash[:notice] = "Newsletter queued to #{count} #{"subscriber".pluralize(count)}."
    else
      flash[:publish_error] = "This post can’t be sent — it must be published, not already mailed, and have someone to go to."
    end

    flash[:publishing] = "open"
    redirect_to edit_writing_post_url(@post)
  end

  private
    def set_post
      @post = Post.find_by!(slug: params[:post_id])
    end
end
