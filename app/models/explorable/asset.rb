# One file of an explorable, at the path it was authored under. The bytes live here rather
# than in Active Storage because the whole point is the path: a blob has a filename but no
# directory, and "decks/10-drive.html" is the only thing a request will ever ask for. The
# content type is derived from the name at save time — a stylesheet answering as
# application/octet-stream is a page with no styles.
class Explorable::Asset < ApplicationRecord
  # Nested under an STI subclass, Rails would derive the table from the base class
  # (post_assets); the table is named for what it holds.
  self.table_name = "explorable_assets"

  # touch: the front door's ETag is the post's updated_at, and a changed file is a changed page.
  belongs_to :explorable, touch: true

  MAX_BYTES = 10.megabytes
  # Plain relative segments only: no leading slash, no ".." and no ".", nothing hidden.
  # Anything outside this shape either escapes the bundle or is a request no browser makes.
  PATH_SEGMENT = /\A(?!\.)[\w][\w.\-]*\z/

  before_validation :derive_content_type
  validates :path, presence: true, uniqueness: { scope: :explorable_id }
  validate :path_stays_inside_the_bundle
  validates :content, length: { maximum: MAX_BYTES, too_long: "is over the %{count}-byte limit" }
  validate :content_is_present

  def self.normalize_path(path)
    Pathname.new(path.to_s).cleanpath.to_s.delete_prefix("./")
  end

  def size = content.to_s.bytesize

  # What goes in the Content-Type header. Text is declared UTF-8 — a deck or a script with
  # a curly quote in it must not depend on the browser guessing, and nosniff is on.
  def mime_type
    text? ? "#{content_type}; charset=utf-8" : content_type
  end

  def text?
    content_type.start_with?("text/") || content_type.in?(%w[ application/json application/javascript image/svg+xml application/manifest+json ])
  end

  private
    def derive_content_type
      self.content_type = Marcel::MimeType.for(name: File.basename(path.to_s), declared_type: content_type)
    end

    def path_stays_inside_the_bundle
      return if path.present? && path.split("/").all? { |segment| segment.match?(PATH_SEGMENT) }

      errors.add(:path, "must be a plain relative path (no leading slash, no ..)")
    end

    # An empty file is a real thing (a .nojekyll, say) — nil is the bug.
    def content_is_present
      errors.add(:content, "can't be nil") if content.nil?
    end
end
