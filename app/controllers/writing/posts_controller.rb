class Writing::PostsController < Writing::BaseController
  include AdoptsFeatureImage

  # The workbench (index/new/edit) wears its own distraction-free chrome; preview (show)
  # keeps the public layout so it renders exactly as the live site will.
  layout -> { action_name == "show" ? "application" : "writing" }

  before_action :set_post, only: %i[ show edit update destroy ]

  def index
    # Scheduled posts are drafts with a future stamp; split them out so the dashboard can
    # bucket Drafts / Scheduled / Published cleanly.
    scheduled, drafts = Post.articles.draft.ordered.to_a.partition(&:scheduled?)
    @scheduled = scheduled
    @drafts = drafts
    @published = Post.articles.published.ordered
    # Exact type, not the STI subtree: an HtmlPage listed here would link into the
    # Lexxy pages form, which writes an Action Text body over a raw-HTML record.
    @pages = Page.where(type: "Page").ordered
  end

  def show
  end

  def new
    @post = Post.new
  end

  def edit
  end

  # Two ways in, mirroring #update. A person pressing "Save draft" is a normal Turbo
  # submit that redirects to the new edit URL. The new-post autosave hits this as a
  # silent fetch (an X-Autosave header) the moment there's real content, so the draft
  # exists server-side and every later keystroke autosaves — the author can lose the
  # tab and keep their work. It answers 201 with the created resource in Location (the
  # PATCH target; the JS adopts it verbatim). Guarded so blank drafts can't proliferate:
  # an autosave create with neither title nor body is refused. A body-first draft (no
  # title yet) persists anyway — the model fills an "Untitled" placeholder on drafts.
  def create
    @post = Post.new(post_params)
    return head :unprocessable_entity if autosave_request? && !draft_content?

    if @post.save
      adopt_feature_image_upload(@post)
      if autosave_request?
        head :created, location: writing_post_url(@post)
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
  # X-Autosave header, slug omitted): on success it answers 204 so nothing repaints and
  # the cursor never jumps; on a validation failure it answers a bodyless 422 so a bad
  # keystroke can't repaint the page either — autosave stays as invisible as it is on
  # success. An explicit save (the Save button, or committing an edited slug/feature
  # image) is a normal Turbo submit: a changed slug redirects once to the new edit URL,
  # and a validation failure re-renders the form with its errors, the way a person
  # pressing Save expects.
  def update
    slug_was = @post.slug
    if @post.update(post_params)
      adopt_feature_image_upload(@post)
      if @post.slug == slug_was
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
    redirect_to writing_root_url
  end

  private
    def set_post
      # Unfiltered on purpose: pages (About, etc) are edited through here too.
      @post = Post.find_by!(slug: params[:id])
    end

    def post_params
      params.require(:post).permit(:title, :slug, :excerpt, :feature_image, :feature_image_caption, :meta_title, :meta_description, :body, :uploaded_feature_image, tag_ids: [])
    end

    def autosave_request?
      request.headers["X-Autosave"].present?
    end

    # A draft is only worth minting once the author has typed something; keeps blank
    # drafts from piling up if the create endpoint is hit with an empty form.
    def draft_content?
      post_params[:title].present? || post_params[:body].present?
    end
end
