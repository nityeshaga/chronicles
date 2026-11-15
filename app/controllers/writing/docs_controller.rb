class Writing::DocsController < Writing::BaseController
  include AdoptsFeatureImage

  layout "writing"

  before_action :set_doc, only: %i[ edit update destroy ]

  def new
    @post = Doc.new
  end

  def edit
    @threads = @post.comments.threads.ordered.includes(:replies)
  end

  # The same mint contract as posts and pages (see Writing::PostsController#create): a doc
  # is written on the same autosaving form, so it owes the client the same answers.
  def create
    @post = Doc.new(doc_params)
    return head :unprocessable_entity if autosave_request? && !draft_content?(doc_params)

    if autosave_request? ? @post.save_keeping_url : @post.save
      if autosave_request?
        render_mint(@post)
      else
        redirect_to edit_writing_doc_url(@post)
      end
    elsif autosave_request?
      head :unprocessable_entity
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    update_from_editor(@post, doc_params)
  end

  def destroy
    @post.destroy
    redirect_to writing_root_url
  end

  private
    def set_doc
      @post = Doc.find(params[:id])
    end

    # A doc has a title and its prose. Nothing a reader would need — no URL, no standfirst,
    # no cover, no meta — because there is no reader.
    def doc_params
      params.require(:doc).permit(:title, :body, :lock_version)
    end
end
