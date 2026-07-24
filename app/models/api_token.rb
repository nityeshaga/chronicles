class ApiToken < ApplicationRecord
  belongs_to :user

  TOKEN_LENGTH = 36

  attr_accessor :plain_token

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  def self.find_by_token(token)
    return nil if token.blank?

    find_by(token_digest: digest_token(token))
  end

  def self.digest_token(token)
    Digest::SHA256.hexdigest(token)
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  private
    def generate_token
      self.plain_token = SecureRandom.urlsafe_base64(TOKEN_LENGTH)
      self.token_digest = self.class.digest_token(plain_token)
    end
end
