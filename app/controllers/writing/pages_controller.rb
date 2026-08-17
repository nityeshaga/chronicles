class Writing::PagesController < Writing::BaseController
  include AdoptsFeatureImage

  # Workbench chrome for new/edit; preview (show) keeps the public layout. Same split as
  # Writing::PostsController.
  layout -> { action_name == "show" ? "application" : "writing" }

  before_action :set_page, only: %i[ show edit update destroy ]

  def show
  end

  def new
    @post = Page.new
  end

  def edit
  end

  # Same mint contract as posts (see Writing::PostsController#create): a page is written
  # on the same autosaving form, so it needs the same 201-plus-stream answer. Without it
  # the autosave POST followed a redirect, never adopted a PATCH URL, and minted a fresh
  # page every two seconds.
  def create
    @post = Page.new(page_params)
    return head :unprocessable_entity if autosave_request? && !draft_content?(page_params)

    if @post.save
      adopt_feature_image_upload(@post)
      if autosave_request?
        render_mint(@post)
      else
        redirect_to edit_writing_page_url(@post)
      end
    elsif autosave_request?
      head :unprocessable_entity
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Same autosave contract as posts (see Writing::PostsController#update): silent 204/422
  # for the debounced fetch, a one-time redirect only when an explicit save renames the slug.
  def update
    slug_was = @post.slug
    if @post.update(page_params)
      adopt_feature_image_upload(@post)
      if @post.slug == slug_was
        head :no_content
      else
        redirect_to edit_writing_page_url(@post)
      end
    elsif autosave_request?
      head :unprocessable_entity
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to writing_root_url
  end

  private
    def set_page
      # Exact type, so an HtmlPage slug 404s here rather than opening in the Lexxy
      # form — saving that form would write an Action Text body over the stored
      # document and silently lose it.
      @post = Page.find_by!(type: "Page", slug: params[:id])
    end

    def page_params
      params.require(:page).permit(:title, :slug, :excerpt, :feature_image, :feature_image_caption, :meta_title, :meta_description, :body, :uploaded_feature_image)
    end
end
