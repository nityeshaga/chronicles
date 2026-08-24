# frozen_string_literal: true

# The screening every whole-document HTML page passes on its way into the database.
# Nothing downstream ever reads these bytes again — no layout, no shared/_meta, no view —
# so a head that arrives without a title, or carrying a canonical pointing at the site the
# document was lifted from, ships silently and stays wrong. This is the one place that
# looks: it refuses what makes a page useless, reports what makes it worse, and writes the
# single tag the app knows better than the author (the canonical, built from the URL the
# page is about to be served at).
#
# An HtmlCard is the same bargain a paragraph at a time — bytes that skip the sanitizer,
# with nothing downstream to catch a mistake in them — so it gets the second screening
# here, in the same voice. That one only ever warns: a card is the author's own markup, and
# refusing it would be refusing the point.
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
  STYLE_ELEMENT = %r{<style\b[^>]*>(.*?)</style>}mi
  # The text before each `{` in a stylesheet — a selector list, unless it runs into an `@`
  # or a `;`, which is how at-rule preludes and declarations stay out of it.
  SELECTOR_LIST = /(?:\A|[{}])\s*([^{}@;]+?)\s*\{/m
  # A selector whose first token is an element name and nothing else. `td.chart` and
  # `td[data-x]` narrow to markup only the card has, so they aren't leaks; `td:hover` is.
  BARE_ELEMENT_SELECTOR = /\A[a-z][a-z0-9]*(?![\w\-.#\[])/i
  KEYFRAME_STOPS = %w[ from to ].freeze
  SCOPE_AT_RULE = "@scope"
  CARD_PEEK_LENGTH = 140
  # Three ways a card works the first time and not the second. Turbo keeps the JavaScript
  # runtime across navigations, and a restoration visit — the back button — paints a cached
  # snapshot without executing anything in it.
  CARD_SCRIPT_HAZARDS = {
    /\bdocument\.write\b/ =>
      "document.write blanks the post on any Turbo visit: running after the document has loaded implicitly reopens it. Draw into an element the card owns instead.",
    /<script\b[^>]*\bsrc\s*=/i =>
      "An external <script src=…> doesn't run on a back-button restore, and nothing orders its load against the card's own code. Inline what the card needs.",
    /\bcustomElements\.define\b/ =>
      "customElements.define throws on the second visit to the post — the registry outlives the navigation, so the name is already taken. Ask customElements.get first, or drop the custom element."
  }.freeze

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

    # An array, where screen_html_document returns a hash: that one also rewrites the
    # document and can reject it, so it has three things to say and the caller has to look
    # at which. This one only ever has warnings, and wrapping them in a one-key hash would
    # promise a decision that isn't there. Empty is the normal answer — describe_html_card
    # is what always has something to say, and it says it somewhere else for that reason.
    def screen_html_card(html)
      html = html.to_s

      [ card_reference_warning(html), card_style_warning(html), *card_script_warnings(html) ].compact
    end

    # What landed, said for every card — the line that catches the mistake no rule can name
    # in advance: an agent that meant to store a chart and stored an empty div reads its own
    # byte count and sees it. The peek is the card's static form, literally what a subscriber
    # gets, so markup that arrived escaped shows up here as its own source code rather than
    # as prose. It rides its own response key: a warning that fires every time is one an
    # agent learns to skim past, and takes the real warnings with it.
    def describe_html_card(html)
      text = card_peek(html)
      return "Stored #{html.bytesize} bytes with no text outside its script and style. Email, feeds and the excerpt will show an empty card — right for a chart that draws itself, a mistake for anything meant to be read." if text.blank?

      "Stored #{html.bytesize} bytes. With script and style pruned the card reads as: #{text} — that's what email, feeds and search descriptions get."
    end

    def card_peek(html)
      ActionText::Fragment.wrap(HtmlCard.new(content: html).static_html).to_plain_text.squish.truncate(CARD_PEEK_LENGTH)
    end

    # A document's failure one level in: the post is served at /<slug>/, so a card's
    # "img/chart.png" is looked for underneath it and 404s. Site-absolute paths get no note
    # here — unlike a lifted document, a card is written for this blog, so "/x.png" is meant.
    def card_reference_warning(html)
      relative = html.scan(ASSET_REFERENCE).flatten.reject do |value|
        value.blank? || value.start_with?("#", "/") || value.match?(ABSOLUTE_REFERENCE)
      end
      return if relative.empty?

      "Relative references won't resolve — the post is served at /<slug>/, so #{sampled(relative)} is looked for underneath it and 404s. Use absolute URLs; upload_image returns one."
    end

    # A card's <style> is served into the article, not into a shadow root, so "td { … }"
    # restyles every table in the post. This reads the CSS by eye rather than parsing it,
    # and a style block that mentions @scope is taken at its word — which is the reason it
    # warns rather than refuses.
    def card_style_warning(html)
      bare = html.scan(STYLE_ELEMENT).flatten.reject { |css| css.include?(SCOPE_AT_RULE) }.flat_map { |css| bare_element_selectors(css) }
      return if bare.empty?

      "Bare element selectors in the card's <style> (#{sampled(bare)}) style the whole article, not just the card — a heuristic read of the CSS, so check it. Put the rules inside @scope { … }, or give every selector a class the card owns."
    end

    def bare_element_selectors(css)
      css.scan(SELECTOR_LIST).flatten.flat_map { |list| list.split(",") }.filter_map do |selector|
        selector = selector.strip
        selector if selector.match?(BARE_ELEMENT_SELECTOR) && !KEYFRAME_STOPS.include?(selector.downcase)
      end
    end

    def card_script_warnings(html)
      CARD_SCRIPT_HAZARDS.filter_map { |hazard, warning| warning if html.match?(hazard) }
    end

    def sampled(values)
      unique = values.uniq
      shown = unique.first(SAMPLED_REFERENCES).join(", ")
      unique.size > SAMPLED_REFERENCES ? "#{shown} (+#{unique.size - SAMPLED_REFERENCES} more)" : shown
    end
end
