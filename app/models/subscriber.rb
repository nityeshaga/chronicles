class Subscriber < ApplicationRecord
  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: true
end
