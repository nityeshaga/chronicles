class Writing::TagsController < Writing::BaseController
  layout "writing"

  before_action :set_tag, only: %i[ edit update ]

  def index
    @tags = Tag.order(:name)
  end

  def edit
  end

  # Slug edits break the tag's public /tag/:slug URL, so the form fences a slug change
  # behind a turbo_confirm; by the time we're here the author has already agreed.
  def update
    if @tag.update(tag_params)
      redirect_to writing_tags_url, notice: "Tag updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Minting a tag is now a deliberate act of its own (not a side effect of autosaving a
  # post): a small form POSTs a name here, we create-or-find the tag, attach it to the
  # post being edited, and stream back the refreshed checkbox list so it appears checked.
  def create
    name = params[:tag_name].to_s.strip
    @post = Post.find_by(id: params[:post_id])
    return head :unprocessable_entity unless @post

    # A name that parameterizes to nothing (e.g. "???" or a non-Latin script) can't yield
    # a valid slug, so treat it like a blank name and mint nothing.
    if name.present? && name.parameterize.present?
      @tag = Tag.find_or_create_by!(slug: name.parameterize) { |t| t.name = name }
      @post.tags << @tag if @post.tag_ids.exclude?(@tag.id)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: writing_root_url }
    end
  end

  private
    def set_tag
      @tag = Tag.find_by!(slug: params[:id])
    end

    def tag_params
      params.require(:tag).permit(:name, :slug, :description)
    end
end
