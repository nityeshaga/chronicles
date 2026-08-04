class Writing::HtmlPagesController < Writing::BaseController
  # The workbench chrome for the form; preview (show) wears no layout at all — see #show.
  layout "writing"

  before_action :set_html_page, only: %i[ show edit update destroy ]

  # Preview is the whole point of this action: an HTML page IS its document, so the only
  # honest preview is the document itself, rendered exactly the way PostsController#show
  # will render it once published — same bytes, same absence of layout. Behind writer auth
  # (inherited from ApplicationController), so a draft can be eyeballed at full fidelity
  # while it's still 404ing for the public.
  def show
    render html: @post.raw_html.html_safe, layout: false
  end

  def new
    @post = HtmlPage.new
  end

  def edit
  end

  def create
    @post = HtmlPage.new(html_page_params)
    if @post.save
      redirect_to edit_writing_html_page_url(@post)
    else
      render :new, status: :unprocessable_entity
    end
  end

  # No autosave here, deliberately: a whole hand-authored document in a debounced save
  # loop buys nothing, so saving is an explicit act and there's no X-Autosave contract to
  # honour. Every save lands back on the editor — and because the URL is built from the
  # record, renaming the slug moves the editor with it rather than stranding the author on
  # a dead address.
  def update
    if @post.update(html_page_params)
      redirect_to edit_writing_html_page_url(@post), notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to writing_root_url
  end

  private
    def set_html_page
      @post = HtmlPage.find_by!(slug: params[:id])
    end

    # Title and slug are the record's own identity; raw_html is the document. Nothing else
    # applies — no excerpt, no feature image, no meta fields, no tags: the document carries
    # its own head, and staying untagged is what keeps HTML pages off the era shelves.
    def html_page_params
      params.require(:html_page).permit(:title, :slug, :raw_html)
    end
end
