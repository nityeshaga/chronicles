class Post < ApplicationRecord
  # The stand-in a title-less draft wears so body-first writing can autosave (see
  # #fill_placeholder_title). Nothing wearing it is fit to publish.
  PLACEHOLDER_TITLE = "Untitled"

  has_rich_text :body
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  # A native feature-image upload. The bytes live in Active Storage; the resolved URL
  # is adopted into the feature_image column on save (see the controller), so every
  # renderer keeps reading one source of truth. See #feature_image_url for the seam.
  has_one_attached :uploaded_feature_image

  enum :status, %w[ draft published ].index_by(&:itself), default: :draft

  scope :ordered, -> { order(published_at: :desc, created_at: :desc) }
  # Just the blog articles, excluding STI Pages (About, etc). The public post feeds,
  # sitemaps and the writing index all want articles only; naming it keeps the
  # type discriminator out of controllers.
  scope :articles, -> { where(type: "Post") }

  # Title and subtitle are single-line by design; squish out any newline that sneaks
  # past the editor (paste, older clients) so headlines never carry hard breaks.
  normalizes :title, :excerpt, with: ->(text) { text.squish }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  # Anything on its way to the public — live now, or a draft with a schedule waiting to
  # fire — must carry a title someone chose. A validation rather than a guard inside the
  # publish verbs, because the verbs are not the only way in: the scheduled job calls
  # publish_now directly, hours after anyone was watching, and a title cleared in the
  # meantime would put /untitled/ on the site at an address no rename takes back.
  validate :real_title_before_going_live, if: -> { published? || scheduled? }

  # A draft may arrive title-less — body-first writing, where every autosave keeps
  # sending the still-empty title field — so re-fill the placeholder rather than fail
  # presence each save. A typed title always wins; a published post still demands a real
  # one. Runs before generate_slug so a fresh untitled draft slugs as "untitled", and
  # since generate_slug only fires on a blank slug, re-filling never churns the slug.
  before_validation :fill_placeholder_title
  before_validation :generate_slug, on: :create
  before_save :stamp_published_at

  def to_param = slug

  # The image the site renders. The feature_image URL column is the source of truth —
  # Ghost's legacy /content/images paths and external URLs live there and stay
  # first-class. A native upload is adopted INTO that column on save, so this resolver
  # normally just mirrors it; the attachment branch is the pre-adoption fallback and
  # lets callers ask for "the feature image" without caring how it arrived.
  def feature_image_url
    return feature_image if feature_image.present?

    Rails.application.routes.url_helpers.rails_blob_path(uploaded_feature_image, only_path: true) if uploaded_feature_image.attached?
  end

  # --- Publishing verbs (the model owns the consequence; the controller calls one) ---

  # The verb every caller reaches for: publish now, or — if handed a future time —
  # schedule it (the post stays a hidden draft and a job flips it live when the clock
  # catches up). Answers false and leaves the reason in #errors, so a controller or a
  # tool can say why without knowing the rule. The verbs underneath raise instead, which
  # is what stops any other path from writing a state the validations forbid.
  def publish(at: nil)
    at = parse_time(at)
    at&.future? ? publish_at(at) : publish_now
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Never given a title anyone chose — either blank, or still wearing the placeholder.
  # What the editor asks before it offers to publish.
  def untitled? = title.blank? || title == PLACEHOLDER_TITLE

  def publish_now
    update!(status: :published, published_at: Time.current)
  end

  def publish_at(time)
    # Floor to a whole second so the stored stamp and the time the job carries
    # round-trip identically. SQLite truncates published_at to microseconds while
    # the job serializer keeps nanoseconds, so a sub-second stamp (what Time.now
    # yields on Linux) would break publish_if_due's identity check. Sub-second
    # schedule precision is meaningless for a blog.
    time = time.floor
    update!(status: :draft, published_at: time)
    Post::PublishJob.set(wait_until: time).perform_later(self, time)
  end

  # Back to draft. A still-pending schedule is cancelled by clearing its future
  # stamp, so the queued job finds nothing due and no-ops.
  def unpublish
    self.status = :draft
    self.published_at = nil if published_at&.future?
    save!
  end

  # Called by the scheduled job, which carries the time it was scheduled for. Fires
  # only if the post is still the draft that schedule stamped — published_at is the
  # identity check. Any re-stamp since (publish-now, reschedule, unpublish) shifts
  # published_at, so a stale job no longer matches and no-ops. Without this a job
  # queued for Fri would republish a post the author explicitly unpublished on Thu.
  def publish_if_due(scheduled_for)
    # The forgiving verb on purpose: a schedule set on a titled post whose title was
    # cleared before the job fired is refused by the validation, and a job that raised
    # there would retry that refusal forever. It stays a draft instead.
    publish if draft? && published_at == scheduled_for
  end

  # A future publish stamp on a draft is a schedule waiting to fire.
  def scheduled? = draft? && published_at&.future? || false

  # --- Newsletter (the model owns the guard + the stamp; the fan-out is a job) ---

  # Mail this post to every subscriber, once. Stamping newsletter_sent_at up front is
  # the idempotency guard: a double-clicked button or a re-POSTed form finds the post
  # already stamped and no-ops, so no subscriber gets the same issue twice. The trade
  # is that a total enqueue failure would still read as "sent" — acceptable here,
  # because double-mailing a personal list is the worse outcome to protect against.
  def deliver_newsletter
    return false unless newsletter_ready?

    # The recipient count is part of the stamp: the list keeps moving after the
    # send, so "mailed to 142" must record 142 as it was in that moment.
    update!(newsletter_sent_at: Time.current, newsletter_recipients_count: Subscriber.count)
    Post::NewsletterJob.perform_later(self)
    true
  end

  def newsletter_sent? = newsletter_sent_at.present?

  # Only a live post that hasn't already gone out, and has somebody to go out to, can be
  # mailed. The empty list belongs here rather than in the view: the send is one-shot, so
  # a stale tab posting after the last subscriber leaves would otherwise burn the stamp
  # and record "mailed to 0".
  def newsletter_ready? = published? && !newsletter_sent? && Subscriber.any?

  # The description Ghost puts in og:/twitter:/JSON-LD: a custom excerpt if the
  # author wrote one, otherwise an auto-excerpt derived from the body. Never blank,
  # so social cards always have text. (Derive, don't store — no second source of truth.)
  def summary
    excerpt.presence || derived_excerpt
  end

  # The plain <meta name="description">, which Ghost emits ONLY when an explicit
  # description exists (custom meta description or excerpt) — nil means "omit the tag".
  def explicit_description
    meta_description.presence || excerpt.presence
  end

  # View seams so shared/_meta and posts/show stay polymorphic instead of
  # branching on is_a?(Page). Page overrides each.
  def og_type = "article"
  def body_class = "post-template"
  def article_meta? = true
  def show_title? = true
  # Only blog articles mail the list; Pages/HtmlPages share the publish popover but
  # have no newsletter route. Page overrides this to false.
  def newsletterable? = true

  # Which tab of the writing dashboard this record answers to. An article splits by its
  # own publish state; the page kinds are a bucket each whatever their state, because
  # that is how the writer looks for them. Page and HtmlPage override.
  def dashboard_bucket
    return "scheduled" if scheduled?

    published? ? "published" : "draft"
  end

  private
    # Ghost's fallback: strip the HTML to plain text, collapse whitespace, and cut
    # at a word boundary near 300 chars (no ellipsis), matching its excerpt helper.
    def derived_excerpt
      text = ActionController::Base.helpers.strip_tags(body.to_s).squish
      return text if text.length <= 300

      text[0, 300].sub(/\s+\S*\z/, "")
    end

    def real_title_before_going_live
      errors.add(:title, "is still the placeholder — name the post before it goes live") if title == PLACEHOLDER_TITLE
    end

    def fill_placeholder_title
      self.title = PLACEHOLDER_TITLE if title.blank? && draft?
    end

    # Slugs are unique, but titles aren't — two "Untitled" autosave drafts (or two posts
    # honestly sharing a name) must both persist, so suffix a counter until the slug is free.
    # Free means what it means to the editor's live check: Slug says, for both of us.
    def generate_slug
      return if slug.present?

      base = title.to_s.parameterize
      candidate = base
      n = 2
      while Slug.new(candidate).taken?
        candidate = "#{base}-#{n}"
        n += 1
      end
      self.slug = candidate
    end

    def stamp_published_at
      self.published_at ||= Time.current if published? && will_save_change_to_status?
    end

    def parse_time(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return if value.blank?

      Time.zone.parse(value.to_s)
    end
end
