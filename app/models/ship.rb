# One thing shipped, the day it shipped: an app, a tool, an explorable, a comic or a
# chronicle. Most of them live off-site — on X, on GitHub, on another domain — so a ship is
# not a Post. It is its own numbered entry in the log that may point at a post, an HTML page
# or an explorable here (post), and at the post that tells how it was built (how_built_post).
#
# The number is the ship's public name (№ 017) and is minted when it goes live, so drafts
# never hold a slot in the sequence and the log has no gaps.
class Ship < ApplicationRecord
  belongs_to :post, optional: true
  belongs_to :how_built_post, class_name: "Post", optional: true

  # A muted looping mp4 or a still; the poster is the first frame a video shows before it plays.
  has_one_attached :preview
  has_one_attached :poster

  enum :kind, %w[ app tool explorable comic chronicle ].index_by(&:itself), validate: true
  enum :built_by, %w[ nityesh luo together ].index_by(&:itself), validate: true, prefix: true
  enum :status, %w[ draft published ].index_by(&:itself), default: :draft

  normalizes :title, with: ->(text) { text.squish }

  validates :title, :shipped_on, presence: true
  validates :number, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  # Door 1 is rendered straight into an href, so only a web address may be saved there.
  validates :check_it_out_url, format: { with: %r{\Ahttps?://[^\s/]+\S*\z}i, message: "must start with http:// or https://" }, allow_blank: true

  scope :ordered, -> { order(shipped_on: :desc, number: :desc, id: :desc) }
  # What the reader sees: everything live, newest first. Same-day ships keep their
  # numbering order, so a batch shipped together reads top-down as it was logged.
  scope :log, -> { published.ordered }
  # Skills and parts: the tools whose door one opens a repository.
  scope :on_github, -> { where("check_it_out_url LIKE ?", "https://github.com/%") }

  def self.by_month = log.group_by { |ship| ship.shipped_on.beginning_of_month }

  # Take a draft live, minting its number on the way if it hasn't one. A number, once
  # given, is never given again — the unique index is the guard.
  def publish
    transaction do
      self.number ||= next_number
      update!(status: :published, published_at: Time.current)
    end
  end

  # Door 1. An explicit URL wins; a ship that announces something on this site opens there.
  def check_it_out_url
    super.presence || post&.public_url
  end

  # The X post that announced it. The log's media frame opens here, because the preview
  # is a trim of the full video that lives on X.
  def x_url
    "https://x.com/#{Setting.current.twitter_handle.delete_prefix("@")}/status/#{x_status_id}" if x_status_id.present?
  end

  # What the log frames for this ship: a looping video, a still, the linked post's cover,
  # or nothing. The preview's own bytes decide, so the same attachment serves either way.
  def media_kind
    if preview.attached?
      preview.video? ? :video : :image
    elsif post&.feature_image_url.present?
      :cover
    end
  end

  # Absolute for the tools' answers, path for the page. Both name the proxy route
  # outright: the app-wide default is the redirect route (upload_image's permanent URLs
  # depend on it), and a <video> tag can't follow a 302 with a Range request.
  def preview_url = media_url(preview)
  def poster_url = media_url(poster)
  def preview_path = media_path(preview)
  def poster_path = media_path(poster)

  private
    def next_number
      (Ship.maximum(:number) || 0) + 1
    end

    def media_url(attachment)
      return unless attachment.attached?

      Rails.application.routes.url_helpers.rails_storage_proxy_url(
        attachment,
        host: Setting.current.production_host,
        protocol: "https"
      )
    end

    def media_path(attachment)
      Rails.application.routes.url_helpers.rails_storage_proxy_path(attachment, only_path: true) if attachment.attached?
    end
end
