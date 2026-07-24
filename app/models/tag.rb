class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  # A tag's name and slug are rendered inside every `cache post` fragment (the tag
  # link on each row/article) and fold into the post's fresh_when ETag. Renaming a
  # tag would otherwise serve the old name and a 404ing slug — and 304-confirm it —
  # until the post itself changed. Touch the posts so those fragments and ETags bust.
  after_update_commit :touch_posts, if: -> { saved_change_to_name? || saved_change_to_slug? || saved_change_to_description? }

  def to_param = slug

  # --- Eras: the homepage "library" shelf ---
  # An "era" is a tag whose description opens with the years it spans, e.g.
  # "2017–2019. In a past life…". That leading range is what shelves the books
  # left-to-right (oldest first) and labels each spine. A plain topical tag has no
  # such prefix and never appears on the shelf. Sorted by the starting year.
  def self.eras
    all.select(&:era?).sort_by(&:era_start_year)
  end

  def era? = description.to_s.match?(/\A\s*\d{4}/)

  def era_start_year = description.to_s[/\A\s*(\d{4})/, 1].to_i

  # The range exactly as written — "2017–2019", "2025–now" — for the legend's right rail.
  def era_years = description.to_s[/\A\s*(\d{4}\s*[–-]\s*(?:\d{4}|now))/, 1]

  # The description with its leading year range trimmed off, for the italic blurb
  # (the years already live on the right, so repeating them reads worse).
  def era_blurb
    description.to_s.sub(/\A\s*\d{4}\s*[–-]\s*(?:\d{4}|now)\s*[.·—–-]*\s*/, "").strip
  end

  # Published articles filed under this era. Memoized because the shelf asks twice
  # (once to drop empty eras, once to print the count).
  def published_article_count
    @published_article_count ||= posts.articles.published.count
  end

  private
    def generate_slug
      self.slug = name.to_s.parameterize if slug.blank?
    end

    def touch_posts
      posts.touch_all
    end
end
