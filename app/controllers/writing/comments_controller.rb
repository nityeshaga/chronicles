# A doc's margin. Every answer here is the margin itself, redrawn: the index is the one
# renderer, and creating or deleting a comment redirects to it, so the frame on the page
# is repainted by the same template whether the writer changed it, the agent did over MCP,
# or the page is only asking what's new.
class Writing::CommentsController < Writing::BaseController
  before_action :set_doc

  def index
    @threads = @doc.comments.threads.ordered.includes(:replies)
    render layout: false
  end

  def create
    comment = @doc.comments.new(comment_params.merge(author_name: Current.user.name))

    if comment.save
      redirect_to writing_doc_comments_url(@doc)
    else
      head :unprocessable_entity
    end
  end

  def destroy
    @doc.comments.find(params[:id]).destroy
    redirect_to writing_doc_comments_url(@doc)
  end

  private
    def set_doc
      @doc = Doc.find(params[:doc_id])
    end

    def comment_params
      params.require(:comment).permit(:body, :quote, :prefix, :parent_id)
    end
end
