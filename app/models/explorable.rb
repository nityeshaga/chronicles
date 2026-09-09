# An HTML page that arrives with company: a whole directory of hand-authored files —
# decks, stylesheets, scripts, images — served as written under one root slug. Every file,
# index.html included, is an asset at the path it was authored under, so the relative links
# inside the bundle resolve exactly as they did on the author's disk and "index.html" is
# just another path. The inherited document (raw_html) reads and writes the index.html
# asset, which is what lets everything an HtmlPage already knows — the full-document check,
# the canonical, the writer's editor, draft 404s, publishing, the sitemap — hold for the
# front door without a second copy of it anywhere.
class Explorable < HtmlPage
  INDEX = "index.html"
  # An attribute, not a script's `a.href = 'decks/' + …`: whitespace before the name.
  REFERENCE = /(?<=\s)(?:src|href)\s*=\s*["']([^"'#?]*)/i
  ABSOLUTE = %r{\A(?://|/|[a-z][a-z0-9+.\-]*:)}i

  has_many :assets, class_name: "Explorable::Asset", inverse_of: :explorable, autosave: true, dependent: :destroy

  def dashboard_bucket = "explorable"

  # The document IS the index.html asset. Derive, don't store: the column stays empty.
  # Bytes come back from the binary column untagged; the document is text.
  def raw_html = index.content&.dup&.force_encoding(Encoding::UTF_8)
  def raw_html=(html)
    index.content = html
  end

  # A found index is not in the association's loaded target, so autosave can't see it.
  after_save { @index.save! if @index&.changed? }

  def reload(...)
    @index = nil
    super
  end

  # A request for a file, or for a directory (`decks/`, `decks`, or the root) — which is a
  # request for its index.
  def asset_at(path)
    path = Explorable::Asset.normalize_path(path)
    assets.find_by(path: [ path, Explorable::Asset.normalize_path(File.join(path, INDEX)) ].uniq)
  end

  # Add-or-replace by path. One transaction, so a bundle lands whole or not at all.
  def write_files(files)
    transaction do
      files.each do |file|
        asset = file[:path] == INDEX ? index : assets.find_or_initialize_by(path: file[:path])
        asset.update!(content: file[:content])
      end
    end
  end

  # Every relative src/href in the bundle's HTML that names a path the bundle doesn't
  # carry. The self-contained contract for an HtmlPage is "no relative references"; for an
  # explorable it's "every relative reference resolves", and this is the check.
  def missing_references
    known = assets.pluck(:path)
    assets.where(content_type: "text/html").pluck(:path, :content)
          .flat_map { |from, html| relative_references(html.to_s.dup.force_encoding(Encoding::UTF_8).scrub, from) }
          .uniq
          .reject { |target| known.include?(target) || known.include?(File.join(target, INDEX)) }
  end

  private
    def index
      @index ||= assets.find_or_initialize_by(path: INDEX)
    end

    def relative_references(html, from)
      html.scan(REFERENCE).flatten.filter_map do |value|
        next if value.blank? || value.match?(ABSOLUTE) || value.include?("${")

        Explorable::Asset.normalize_path(File.join(File.dirname(from), value))
      end
    end
end
