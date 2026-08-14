# A machine is one shipped product on the homepage shelf. The shelf is data,
# not markup: config/machines.yml holds the facts (blurbs in each product's own
# landing-page language, screenshots in app/assets/images/machines/), and
# bin/refresh-machines keeps updated_at true from each repo's latest default-
# branch commit — so the shelf reorders itself as things actually ship.
# launched_at is history and never moves: the day the product was announced.
class Machine < Data.define(:slug, :name, :url, :repo, :blurb, :launched_at, :updated_at)
  def self.all
    YAML.load_file(source).map { |attrs| new(**attrs.symbolize_keys) }.sort_by(&:updated_at).reverse
  end

  # Folded into the homepage ETag so a data-only reshuffle can't be 304'd away.
  def self.cache_key
    Digest::MD5.file(source).hexdigest
  end

  def self.source
    Rails.root.join("config/machines.yml")
  end

  def launched_on
    Date.parse(launched_at)
  end

  def updated_on
    Date.parse(updated_at)
  end
end
