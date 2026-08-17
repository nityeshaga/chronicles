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
    @records = Post.order(updated_at: :desc).includes(:tags)
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
  # PATCH target; the JS adopts it verbatim) and the record's id in X-Post-Id — what the
  # rest of the editor needs to name a record that now exists, since a slug-shaped
  # identity goes stale the next time the slug changes. Guarded so blank drafts can't
  # proliferate: an autosave create with neither title nor body is refused. A body-first
  # draft (no title yet) persists anyway — the model fills an "Untitled" placeholder.
  def create
    @post = Post.new(post_params)
    return head :unprocessable_entity if autosave_request? && !draft_content?

    if @post.save
      adopt_feature_image_upload(@post)
      if autosave_request?
        head :created, location: writing_post_url(@post), x_post_id: @post.id
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

    def autosave_request?
      request.headers["X-Autosave"].present?
    end

    # A draft is only worth minting once the author has typed something; keeps blank
    # drafts from piling up if the create endpoint is hit with an empty form.
    def draft_content?
      post_params[:title].present? || post_params[:body].present?
    end
end
