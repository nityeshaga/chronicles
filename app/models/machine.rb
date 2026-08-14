# A machine is one shipped product on the homepage shelf. The shelf is data,
# not markup: config/machines.yml holds the facts (blurbs in each product's own
# landing-page language, screenshots in app/assets/images/machines/), and
# bin/refresh-machines keeps shipped_at true from each repo's latest default-
# branch commit — so the shelf reorders itself as things actually ship.
class Machine < Data.define(:slug, :name, :url, :repo, :blurb, :shipped_at)
  def self.all
    YAML.load_file(source).map { |attrs| new(**attrs.symbolize_keys) }.sort_by(&:shipped_at).reverse
  end

  # Folded into the homepage ETag so a data-only reshuffle can't be 304'd away.
  def self.cache_key
    Digest::MD5.file(source).hexdigest
  end

  def self.source
    Rails.root.join("config/machines.yml")
  end

  def shipped_on
    Date.parse(shipped_at)
  end
end
