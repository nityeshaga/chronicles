# Resolving a thread is creating its resolution; reopening it destroys that.
class Writing::Comments::ResolutionsController < Writing::BaseController
  before_action :set_thread

  def create
    @thread.resolve
    redirect_to writing_doc_comments_url(@thread.doc)
  end

  def destroy
    @thread.reopen
    redirect_to writing_doc_comments_url(@thread.doc)
  end

  private
    def set_thread
      @thread = Doc.find(params[:doc_id]).comments.threads.find(params[:comment_id])
    end
end
