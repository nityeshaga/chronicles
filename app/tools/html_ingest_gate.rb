# frozen_string_literal: true

# The screening every whole-document HTML page passes on its way into the database.
# Nothing downstream ever reads these bytes again — no layout, no shared/_meta, no view —
# so a head that arrives without a title, or carrying a canonical pointing at the site the
# document was lifted from, ships silently and stays wrong. This is the one place that
# looks: it refuses what makes a page useless, reports what makes it worse, and writes the
# single tag the app knows better than the author (the canonical, built from the URL the
# page is about to be served at).
#
# Only the MCP tools include this. A human pasting a document into the writing textarea is
# looking at their own markup and doesn't need a chaperone — and injecting a tag into a
# document someone is actively editing would fight their next save.
module HtmlIngestGate
  HEAD_ELEMENT = %r{<head\b[^>]*>(.*?)</head>}mi
  TITLE_ELEMENT = %r{<title\b[^>]*>\s*\S.*?</title>}mi
  META_DESCRIPTION = /<meta\b[^>]*\bname\s*=\s*["']?description\b[^>]*>/i
  CANONICAL_LINK = /<link\b[^>]*\brel\s*=\s*["']?canonical\b[^>]*>/i
  HREF_VALUE = /\bhref\s*=\s*["']([^"']*)["']/i
  HEAD_CLOSE = %r{</head>}i
  ASSET_REFERENCE = /\b(?:src|href)\s*=\s*["']([^"']*)["']/i
  # A scheme (http:, mailto:, data:) or a protocol-relative host — anything that resolves
  # somewhere other than this blog's routing table.
  ABSOLUTE_REFERENCE = %r{\A(?://|[a-z][a-z0-9+.\-]*:)}i
  SAMPLED_REFERENCES = 5

  private
    # Returns { error: } when the document can't be published as it stands, otherwise
    # { html:, warnings: } — the html to store, byte-identical to what came in apart from
    # the canonical link.
    def screen_html_document(html, canonical_url:)
      head = html[HEAD_ELEMENT, 1]

      unless head&.match?(TITLE_ELEMENT)
        return { error: "The document has no <title> in its <head>. That string is the browser tab, the search result and the fallback social card — add <title>…</title> and resend." }
      end

      warnings = []
      unless head.match?(META_DESCRIPTION)
        warnings << %(No <meta name="description"> in the head: the page publishes SEO-naked, and search results will quote whatever text they find first.)
      end

      html, canonical_warning = resolve_canonical(html, canonical_url)
      warnings << canonical_warning if canonical_warning
      warnings.concat(reference_warnings(html))

      { html: html, warnings: warnings }
    end

    # The canonical is the one head tag the app computes better than the author: it knows
    # the URL these bytes are about to be served at, and a landing page that also lives on
    # its old host splits its own ranking without one. Injection is keyed on absence, so
    # re-editing never leaves a second tag; a canonical aimed at this site under some other
    # path (the shape a slug rename leaves behind) is corrected; one aimed anywhere else is
    # the author making a deliberate choice, so it's left alone and reported instead.
    def resolve_canonical(html, canonical_url)
      tag = html[CANONICAL_LINK]
      return [ html.sub(HEAD_CLOSE) { |close| "#{canonical_tag(canonical_url)}\n#{close}" }, nil ] if tag.nil?

      href = tag[HREF_VALUE, 1].to_s
      return [ html, nil ] if href == canonical_url

      if href.blank? || same_site?(href, canonical_url)
        [ html.sub(CANONICAL_LINK) { canonical_tag(canonical_url) },
          "The document's canonical pointed at #{href.presence || 'no URL at all'} — rewritten to #{canonical_url}, the URL this page is served at." ]
      else
        [ html,
          "The document already carries a canonical pointing at #{href}, so none was injected and it was left as written. If that isn't the URL you want ranking, change it in the document." ]
      end
    end

    def canonical_tag(canonical_url)
      %(<link rel="canonical" href="#{canonical_url}">)
    end

    # Same site means ours to keep correct. A root-relative or protocol-relative href
    # carries no host of its own, so it already resolves against this blog.
    def same_site?(href, canonical_url)
      host = URI.parse(href.strip).host
      host.nil? || host.casecmp?(URI.parse(canonical_url).host.to_s)
    rescue URI::InvalidURIError
      false
    end

    # The contract is a self-contained document. It's served at a root slug, so "img/hero.png"
    # resolves to /img/hero.png — straight into the post router, which answers 404. Anchors
    # and absolute URLs are fine. Site-absolute paths do resolve here, they're just rarely
    # what a document lifted from another host meant, hence the softer note.
    def reference_warnings(html)
      relative = []
      site_absolute = []

      html.scan(ASSET_REFERENCE).flatten.each do |value|
        next if value.blank? || value.start_with?("#") || value.match?(ABSOLUTE_REFERENCE)

        (value.start_with?("/") ? site_absolute : relative) << value
      end

      warnings = []
      if relative.any?
        warnings << "Relative references won't resolve — the document is served at a root slug, so #{sampled(relative)} hits the blog's own routes and 404s. Use absolute URLs; upload_image returns one."
      end
      if site_absolute.any?
        warnings << "Site-absolute references (#{sampled(site_absolute)}) resolve against this blog rather than the document's original home — fine if that's what you meant."
      end
      warnings
    end

    def sampled(values)
      unique = values.uniq
      shown = unique.first(SAMPLED_REFERENCES).join(", ")
      unique.size > SAMPLED_REFERENCES ? "#{shown} (+#{unique.size - SAMPLED_REFERENCES} more)" : shown
    end
end
