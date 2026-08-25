# The id on every heading, derived at render. Ghost stamped ids into the markup and the
# links people hold still end in them — #what-you-will-learn, #ms0-set-up-your-environment
# — but a stored id is a second source of truth the sanitizer strips on the way out and the
# editor drops on the way in, so every one of those links landed at the top of the page.
# Deriving from the heading text at render time keeps the link working for as long as the
# heading reads the same, with nothing to store and nothing to keep in step.
#
# Three sluggers, because the ids serve two different promises. An imported post's anchors
# are already out in the world, so they are rebuilt the way Ghost built them — and Ghost
# built them two ways, branching on the mobiledoc's ghostVersion (@tryghost/kg-utils
# slugify, called from kg-mobiledoc-html-renderer's addHeadingId): posts written under
# Ghost 2 and 3 drop <>&"?, trim, turn every other non-word run into one hyphen and lowercase,
# trailing hyphen after a colon and all; posts written under Ghost 4 drop punctuation, turn
# whitespace into hyphens, trim the hyphens and percent-encode the rest. Both count a repeat
# from -1. Ported character for character, they reproduce all 424 h2–h4 ids the import
# carried (389 from Ghost 3, 35 from Ghost 4). A post written here owes nobody an old link,
# so it gets the anchor a reader would type: "How to debug your code:" →
# #how-to-debug-your-code, a repeat counts up from -2.
module HeadingAnchors
  HEADINGS = "h2, h3, h4"

  def self.add(html, ghost_version: nil)
    slugger = slugger_for(ghost_version)
    seen = Hash.new(0)

    ActionText::Fragment.wrap(html.to_s).update do |source|
      source.css(HEADINGS).each do |heading|
        id = slugger.slug(heading.text)
        next if id.nil?

        repeat = seen[id]
        seen[id] += 1
        heading["id"] = repeat.zero? ? id : slugger.repeat(id, repeat)
      end
    end.to_html.html_safe
  end

  def self.slugger_for(ghost_version)
    return Readable unless ghost_version

    Gem::Version.new(ghost_version) < Gem::Version.new("4") ? Ghost3 : Ghost4
  end

  module Readable
    # Nothing to stamp when nothing survives — a heading in Devanagari, or an emoji alone —
    # rather than an empty id and a run of -2, -3 behind it.
    def self.slug(text) = text.delete("'’").parameterize.presence

    # The second Foo is foo-2.
    def self.repeat(id, nth) = "#{id}-#{nth + 1}"
  end

  # Ghost's renderer counts repeats the same way under both of its sluggers: the second Foo
  # is foo-1.
  module Ghost
    def repeat(id, nth) = "#{id}-#{nth}"
  end

  module Ghost3
    extend Ghost

    def self.slug(text)
      text.delete(%(<>&"?)).gsub(/\A[[:space:]]+|[[:space:]]+\z/, "").gsub(/[^A-Za-z0-9_]/, "-").squeeze("-").downcase
    end
  end

  module Ghost4
    extend Ghost

    PUNCTUATION = %r{[\]\[!"\#$%&'()*+,./:;<=>?@\\^_{|}~]}

    def self.slug(text)
      slug = text.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "").downcase.gsub(PUNCTUATION, "")
        .gsub(/[[:space:]]+/, "-").gsub(/\A-|-{2,}|-\z/, "")
      CGI.escapeURIComponent(slug)
    end
  end
end
