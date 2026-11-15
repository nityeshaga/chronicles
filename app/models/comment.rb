# A note in a doc's margin. One that opens a thread is pinned to a passage: the quote is
# the words it was left on, and the prefix is the few characters before them, which is what
# tells the third "the model" in a paragraph from the first. A reply belongs to its thread
# and is pinned to nothing.
#
# The pin is the words, not a position. Nothing is written into the body, so the prose
# stays exactly what the writer typed, and a comment whose words have since been rewritten
# is not lost: it is still here, quoting what it was about.
class Comment < ApplicationRecord
  belongs_to :doc
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, -> { ordered }, class_name: "Comment", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  scope :threads, -> { where(parent_id: nil) }
  scope :open, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :ordered, -> { order(:created_at, :id) }

  normalizes :quote, with: ->(text) { text.squish.presence }
  normalizes :body, with: ->(text) { text.strip }

  before_validation :join_parents_doc

  validates :body, :author_name, presence: true
  validate :reply_answers_a_thread

  def thread? = parent_id.nil?
  def resolved? = resolved_at.present?

  def resolve
    update!(resolved_at: Time.current)
  end

  def reopen
    update!(resolved_at: nil)
  end

  # Have the words this was left on been rewritten since? Asked of the prose as it reads,
  # the same way the margin asks the page.
  def orphaned? = quote.present? && doc.plain_text.exclude?(quote)

  private
    def join_parents_doc
      self.doc = parent.doc if parent
    end

    # One level, like the margin of a page: a reply to a reply is a reply to the thread.
    def reply_answers_a_thread
      errors.add(:parent, "must be the comment that opened the thread") if parent && !parent.thread?
    end
end
