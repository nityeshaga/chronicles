# A working document: private to the writer, written on the same canvas as a post, and
# never anything else. It is a Post so that everything a post already knows — the editor,
# autosave, the lock that keeps two tabs from trading saves, the MCP tools that read and
# patch a body — holds for it without a second copy. What it adds is the margin: comments
# pinned to a passage, answered in a thread, by the writer and by the agent he works with.
class Doc < Post
  has_many :comments, dependent: :destroy

  # The one promise this kind makes. The public reader only ever sees what is published
  # (Post.viewable), so a doc that cannot be published cannot be read — by any door, the
  # publish tools and the scheduled job included, because they all end in a save.
  validate :stays_private

  # A doc is linked from a chat, a notepad, a comment — and retitled a dozen times while it
  # is being written. Addressed by id, the link survives every one of them.
  def to_param = id&.to_s

  def publishable? = false
  def commentable? = true
  def taggable? = false
  def newsletterable? = false
  def dashboard_bucket = "doc"

  # The prose as a reader would say it aloud: what a quote has to be found in.
  def plain_text = body.to_plain_text.squish

  private
    def stays_private
      errors.add(:base, "A doc is private and can't be published — change its kind to a post first") if published? || published_at.present?
    end
end
