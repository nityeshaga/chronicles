# An HTML page that arrives with company: a whole directory of hand-authored files —
# decks, stylesheets, scripts, images — served as written under one root slug. The entry
# document (index.html) is the inherited raw_html, so everything an HtmlPage already knows
# — the full-document check, the canonical, the writer's preview, draft 404s, publishing,
# the sitemap — holds for the front door; the companion files are assets, each served at
# the path it was authored under, so the relative links inside the bundle resolve exactly
# as they did on the author's disk. Nothing is rewritten on the way in or out.
class Explorable < HtmlPage
  INDEX = "index.html"
  # An attribute, not a script's `a.href = 'decks/' + …`: whitespace before the name.
  REFERENCE = /(?<=\s)(?:src|href)\s*=\s*["']([^"'#?]*)/i
  ABSOLUTE = %r{\A(?://|/|[a-z][a-z0-9+.\-]*:)}i

  has_many :assets, class_name: "Explorable::Asset", dependent: :destroy

  def dashboard_bucket = "explorable"

  # A request for a directory (`decks/`, or just `decks`) is a request for its index.
  def asset_at(path)
    assets.find_by(path: [ path, File.join(path, INDEX) ])
  end

  # Add-or-replace the whole set: index.html becomes the document, everything else an
  # asset keyed on its path. One transaction, so a bundle lands whole or not at all.
  def write_files(files)
    transaction do
      files.each do |file|
        if file[:path] == INDEX
          update!(raw_html: file[:content])
        else
          assets.find_or_initialize_by(path: file[:path]).update!(content: file[:content])
        end
      end
    end
  end

  # Every relative src/href in the document and its HTML assets that names a path the
  # bundle doesn't carry. The self-contained contract for an HtmlPage is "no relative
  # references"; for an explorable it's "every relative reference resolves", and this is
  # the check. Derived on demand, never stored.
  def missing_references
    documents = { INDEX => raw_html.to_s }
    assets.where(content_type: "text/html").each { |asset| documents[asset.path] = asset.content.to_s }
    known = documents.keys + assets.pluck(:path)

    documents.flat_map { |from, html| relative_references(html, from) }
             .uniq
             .reject { |target| known.include?(target) || known.include?(File.join(target, INDEX)) }
  end

  private
    def relative_references(html, from)
      html.scan(REFERENCE).flatten.filter_map do |value|
        next if value.blank? || value.match?(ABSOLUTE) || value.include?("${")

        Explorable::Asset.normalize_path(File.join(File.dirname(from), value))
      end
    end
end
