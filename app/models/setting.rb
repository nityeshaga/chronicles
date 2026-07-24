# The site's identity in one row: the strings a deployer swaps to make this blog
# theirs — title, tagline, author, canonical host, and the social/OG/JSON-LD
# fields the <head>, RSS feed and sitemap read. Ghost baked these into helper
# constants; lifting them into a row is what lets someone fork the repo without
# editing Ruby.
class Setting < ApplicationRecord
  # Raised loudly rather than as RecordNotFound (which ApplicationController turns
  # into a 404) so a fresh checkout that ran db:schema:load without db:seed fails
  # with a fixable message instead of a NoMethodError deep inside a view.
  MissingError = Class.new(StandardError)

  def self.current
    first || raise(MissingError, "No Setting row found — run bin/rails db:seed")
  end
end
