# A note the author leaves on a page of the live site, pinned to one element: "this
# excerpt runs long", "swap this image". Notes are read back over MCP by the agent, who
# does the work and resolves each with a line saying what changed. The page is its
# path and the element is a CSS selector — nothing else identifies them, so the same
# table serves a post, the homepage, a tag page or a verbatim HTML document, and the
# pin lands wherever the element is when the page next renders.
class Note < ApplicationRecord
  belongs_to :user, default: -> { Current.user }

  validates :path, :selector, :body, presence: true
  validates :path, format: { with: %r{\A/}, message: "must be a site path" }

  scope :open,     -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :on,       ->(path) { where(path: path) }
  scope :ordered,  -> { order(:created_at) }

  def resolve(resolution = nil)
    update!(resolved_at: Time.current, resolution: resolution.presence)
  end

  def reopen
    update!(resolved_at: nil, resolution: nil)
  end

  def resolved? = resolved_at.present?
end
