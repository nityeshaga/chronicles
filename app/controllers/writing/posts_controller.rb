class Writing::PostsController < Writing::BaseController
  include AdoptsFeatureImage

  # The workbench (index/new/edit) wears its own distraction-free chrome; preview (show)
  # keeps the public layout so it renders exactly as the live site will.
  layout -> { action_name == "show" ? "application" : "writing" }

  before_action :set_post, only: %i[ show edit update destroy ]

  def index
    # One relation for the whole dashboard, last touched first. The tabs are a client-side
    # filter over a single rendered list, so every tab has to share one sort — and what a
    # writer coming back wants first is the thing he was last working on. Which tab a
    # record answers to is its own business (Post#dashboard_bucket), and so is which
    # editor it links to: the STI class picks the route helper.
    #
    # id breaks the tie because ties are the normal case, not the corner: the Ghost import
    # wrote updated_at across hundreds of rows in one pass, so without it the order inside
    # an imported batch is whatever SQLite feels like returning, and it can differ between
    # two loads of the same page.
    @records = Post.order(updated_at: :desc, id: :desc).includes(:tags)
  end

  def show
  end

  def new
    @post = Post.new
  end

  def edit
  end

  # Two ways in, mirroring #update. The new-post autosave hits this as a silent fetch
  # (an X-Autosave header) the moment there's real content, so the draft exists
  # server-side and every later keystroke autosaves — the author can lose the tab and
  # keep their work. Guarded so blank drafts can't proliferate: an autosave create with
  # neither title nor body is refused. A body-first draft (no title yet) persists anyway
  # — the model fills a placeholder. See Writing::Autosaving for the mint's answer.
  def create
    @post = Post.new(post_params)
    return head :unprocessable_entity if autosave_request? && !draft_content?(post_params)

    if @post.save
      adopt_feature_image_upload(@post)
      if autosave_request?
        render_mint(@post)
      else
        redirect_to edit_writing_post_url(@post)
      end
    elsif autosave_request?
      head :unprocessable_entity
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Two ways in, one action. The debounced autosave hits this as a silent fetch (an
  # X-Autosave header): on success it answers 204 so nothing repaints and the cursor never
  # jumps; on a validation failure it answers a bodyless 422 so a bad keystroke can't
  # repaint the page either — autosave stays as invisible as it is on success. The slug
  # rides that path with everything else, so a rename answers 204 too, with the addresses
  # it moved (see Writing::Autosaving). A slug someone else holds fails the uniqueness
  # validation and lands in the same silent 422: the record keeps the URL it had, and the
  # availability line under the field is what says why.
  #
  # An explicit save (the feature-image file, the only field left off the silent path) is
  # a normal Turbo submit, which can't read headers — so a rename there still redirects
  # once to the new edit URL, and a validation failure re-renders the form with its errors.
  def update
    slug_was = @post.slug
    if @post.update(post_params)
      adopt_feature_image_upload(@post)
      if autosave_request?
        render_autosave(@post, renamed: @post.slug != slug_was)
      elsif @post.slug == slug_was
        head :no_content
      else
        redirect_to edit_writing_post_url(@post)
      end
    elsif autosave_request?
      head :unprocessable_entity
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    # 303, not 302: the browser reaches here on a real DELETE fetch, and a 302 makes it
    # replay DELETE against the redirect target — which has no DELETE route.
    redirect_to writing_root_url, status: :see_other
  end

  private
    def set_post
      # Unfiltered on purpose: pages (About, etc) are edited through here too.
      @post = Post.find_by!(slug: params[:id])
    end

    def post_params
      params.require(:post).permit(:title, :slug, :excerpt, :feature_image, :feature_image_caption, :meta_title, :meta_description, :body, :uploaded_feature_image, tag_ids: [])
    end
end
