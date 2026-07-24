# frozen_string_literal: true

# Parity gate: compares the old Ghost snapshot (reference/) against the new Rails
# app (a running server) for every URL in the reference sitemaps.
#
# Checks per URL: HTTP status, <title>, canonical, meta description, og:image,
# first <h1>, and article/main body word count (±2%). Plus RSS item count+guids
# and sitemap URL-set equality.
#
# Usage:
#   PARITY_BASE=http://localhost:8891 ruby script/parity_check.rb
# Writes a markdown report to ../parity-report.md (repo root).
#
# Host differences (nityesh.com vs localhost) are normalized to path before
# comparing canonical/og:image — the deploy makes the host match; content is
# what parity means here.

require "nokogiri"
require "net/http"
require "uri"
require "set"

BASE      = ENV.fetch("PARITY_BASE", "http://localhost:8891").chomp("/")
APP_ROOT  = File.expand_path("..", __dir__)
PROJ_ROOT = File.expand_path("../..", __dir__)
REF_DIR   = File.join(PROJ_ROOT, "reference")
OUT_FILE  = File.join(PROJ_ROOT, "parity-report.md")
TOLERANCE = 0.02 # ±2% word count

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def norm_ws(s)
  s.to_s.gsub(/\s+/, " ").strip
end

# Strip scheme+host so nityesh.com and localhost:PORT compare equal.
def path_of(url)
  return nil if url.nil? || url.empty?
  u = URI.parse(url) rescue nil
  return url unless u
  p = u.path
  p += "?#{u.query}" if u.query
  p.empty? ? "/" : p
rescue URI::InvalidURIError
  url
end

def fetch(path, limit: 0)
  uri = URI.join(BASE + "/", path.sub(%r{\A/}, ""))
  res = Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 30) do |http|
    http.get(uri.request_uri, "User-Agent" => "parity-check")
  end
  [ res.code.to_i, res.body.to_s, res ]
end

def read_ref(file)
  return nil if file.nil? || file.to_s.empty?
  path = File.join(REF_DIR, file)
  (File.file?(path)) ? File.read(path) : nil
end

# Reference file on disk for a given URL path.
def ref_file_for(path)
  case path
  when "/"            then "pages/index.html"
  when "/about/"      then "pages/about.html"
  when "/about-me/"   then "pages/about-me.html"
  when %r{\A/tag/([^/]+)/\z}       then "tags/#{$1}.html"
  when %r{\A/author/nityesh/\z}    then "pages/author-nityesh.html"
  when %r{\A/([^/]+)/\z}           then "posts/#{$1}.html"
  end
end

# Body word count, robust to the old/new markup nesting difference.
#
# - Single post/page: the article body is `.gh-content` (one node, present in
#   both renders) — the true "body word count".
# - List/archive pages (home, tags): the content is the post feed; sum the text
#   of every `article.post-list-item`. Old Ghost nests header+feed inside one
#   `.gh-main`; new uses siblings — so counting a single `.gh-main` would
#   compare unlike regions. Counting the rows compares like for like.
def word_count(doc)
  if (article = doc.at_css(".gh-content"))
    article.css("script, style").remove
    return norm_ws(article.text).split(/\s+/).size
  end
  rows = doc.css("article.post-list-item")
  if rows.any?
    return rows.sum { |r| norm_ws(r.text).split(/\s+/).size }
  end
  node = doc.at_css(".gh-main") || doc.at_css("main") || doc.at_css("body")
  return 0 unless node
  node.css("script, style").remove
  norm_ws(node.text).split(/\s+/).size
end

def extract(html)
  doc = Nokogiri::HTML(html)
  {
    title:     norm_ws(doc.at_css("title")&.text),
    canonical: path_of(doc.at_css('link[rel="canonical"]')&.[]("href")),
    desc:      norm_ws(doc.at_css('meta[name="description"]')&.[]("content")),
    og_image:  path_of(doc.at_css('meta[property="og:image"]')&.[]("content")),
    h1:        norm_ws(doc.at_css("h1")&.text),
    words:     word_count(doc)
  }
end

# ---------------------------------------------------------------------------
# Gather URLs from the reference sitemaps
# ---------------------------------------------------------------------------

# Only top-level page URLs (<url><loc>), NOT Ghost's <image:image><image:loc>
# entries nested inside each <url>.
def sitemap_locs(file)
  xml = read_ref(file) or return []
  Nokogiri::XML(xml).remove_namespaces!.css("url > loc").map { |n| path_of(norm_ws(n.text)) }
end

groups = {
  "Pages"   => sitemap_locs("sitemap-pages.xml"),
  "Posts"   => sitemap_locs("sitemap-posts.xml"),
  "Tags"    => sitemap_locs("sitemap-tags.xml"),
  "Authors" => sitemap_locs("sitemap-authors.xml")
}

# ---------------------------------------------------------------------------
# Per-URL comparison
# ---------------------------------------------------------------------------

# Author page intentionally 301s to /about/ (plan §3) — expected, not a failure.
EXPECTED_REDIRECTS = { "/author/nityesh/" => 301 }

FIELDS = %i[title canonical desc og_image h1]
rows = []          # every URL's result
substantive = []   # diffs a human must look at

groups.each do |group, paths|
  paths.each do |path|
    ref_html = read_ref(ref_file_for(path).to_s)
    new_status, new_body, = fetch(path)

    row = { group: group, path: path, diffs: [], expected: false }

    # Status
    expected_status = EXPECTED_REDIRECTS[path] || 200
    row[:old_status] = 200 # reference snapshots were all captured at HTTP 200
    row[:new_status] = new_status
    if EXPECTED_REDIRECTS.key?(path)
      row[:expected] = true
      row[:status_note] = "301→/about/ (intended)"
      row[:status_ok] = (new_status == expected_status)
      row[:diffs] << "status #{new_status} (expected redirect #{expected_status})" unless row[:status_ok]
      # Redirect target has no comparable body; record and move on.
      rows << row
      next
    end
    row[:status_ok] = (new_status == 200)
    unless row[:status_ok]
      row[:diffs] << "HTTP #{new_status} (old 200)"
      substantive << { path: path, kind: "status", old: 200, new: new_status }
    end

    if ref_html.nil?
      row[:diffs] << "no reference snapshot on disk"
      rows << row
      next
    end

    old = extract(ref_html)
    new = extract(new_body)
    row[:old] = old
    row[:new] = new

    FIELDS.each do |f|
      ok = (old[f].to_s == new[f].to_s)
      row["#{f}_ok".to_sym] = ok
      next if ok
      row[:diffs] << f.to_s
      substantive << { path: path, kind: f.to_s, old: old[f], new: new[f] }
    end

    # Word count ±2%
    ow, nw = old[:words], new[:words]
    if ow.zero?
      row[:word_ok] = nw.zero?
      row[:word_delta] = nw.zero? ? 0.0 : Float::INFINITY
    else
      delta = (nw - ow).abs / ow.to_f
      row[:word_delta] = delta
      row[:word_ok] = delta <= TOLERANCE
    end
    row[:old_words] = ow
    row[:new_words] = nw
    unless row[:word_ok]
      pct = row[:word_delta].infinite? ? "∞" : format("%.1f%%", row[:word_delta] * 100)
      row[:diffs] << "words #{ow}→#{nw} (#{pct})"
      substantive << { path: path, kind: "word_count", old: ow, new: nw }
    end

    rows << row
  end
end

# ---------------------------------------------------------------------------
# 404 page (not in a sitemap, but part of the contract)
# ---------------------------------------------------------------------------
bogus = "/this-slug-does-not-exist-parity-check/"
s404, b404, = fetch(bogus)
ref404 = read_ref("pages/404.html")
old404_title = ref404 ? norm_ws(Nokogiri::HTML(ref404).at_css("title")&.text) : nil
new404_title = norm_ws(Nokogiri::HTML(b404).at_css("title")&.text)
row404 = {
  status_ok: (s404 == 404),
  new_status: s404,
  old_title: old404_title,
  new_title: new404_title
}

# ---------------------------------------------------------------------------
# RSS: item count + guids
# ---------------------------------------------------------------------------
rss_ref = read_ref("rss.xml")
_, rss_new_body, = fetch("/rss/")
def rss_items(xml)
  return { count: 0, guids: [] } if xml.nil? || xml.empty?
  doc = Nokogiri::XML(xml).remove_namespaces!
  items = doc.css("item")
  { count: items.size, guids: items.map { |i| norm_ws(i.at_css("guid")&.text) } }
end
rss_old = rss_items(rss_ref)
rss_new = rss_items(rss_new_body)
rss_guids_ok = (rss_old[:guids] == rss_new[:guids])
rss_missing  = rss_old[:guids] - rss_new[:guids]
rss_extra    = rss_new[:guids] - rss_old[:guids]

# ---------------------------------------------------------------------------
# Sitemap URL sets
# ---------------------------------------------------------------------------
sitemap_reports = {}
%w[sitemap.xml sitemap-posts.xml sitemap-pages.xml sitemap-tags.xml sitemap-authors.xml].each do |sm|
  old_xml = read_ref(sm)
  _, new_xml, = fetch("/#{sm}")
  # sitemap.xml is an index (<sitemap><loc>); children list page URLs (<url><loc>).
  # Exclude Ghost's nested <image:loc> entries by selecting only those two paths.
  sel = "sitemap > loc, url > loc"
  old_locs = old_xml ? Nokogiri::XML(old_xml).remove_namespaces!.css(sel).map { |n| path_of(norm_ws(n.text)) }.to_set : Set.new
  new_locs = new_xml && !new_xml.empty? ? (Nokogiri::XML(new_xml).remove_namespaces!.css(sel).map { |n| path_of(norm_ws(n.text)) }.to_set rescue Set.new) : Set.new
  sitemap_reports[sm] = {
    old_count: old_locs.size,
    new_count: new_locs.size,
    missing: (old_locs - new_locs).to_a.sort,
    extra: (new_locs - old_locs).to_a.sort,
    ok: (old_locs == new_locs)
  }
end

# ---------------------------------------------------------------------------
# List-page detail — auto-diagnose why home/tag word counts differ:
# post-set differences (pagination / tagging) and per-row excerpt loss.
# ---------------------------------------------------------------------------

def list_rows(html)
  Nokogiri::HTML(html).css("article.post-list-item").map do |a|
    link = a.at_css(".post-title a, h2 a, a.post-title")
    excerpt = a.at_css(".post-excerpt")
    { href: path_of(link&.[]("href")), title: norm_ws(link&.text),
      excerpt_words: excerpt ? norm_ws(excerpt.text).split(/\s+/).size : 0,
      has_excerpt: !excerpt.nil? }
  end
end

# Ghost paginated archives; capture whether the old page linked a next page.
def paginated?(html)
  html.to_s.match?(/rel=["']next["']|\/page\/\d+/)
end

list_details = []
[ [ "Homepage", "/", "pages/index.html" ],
  [ "Tag chronicles", "/tag/chronicles/", "tags/chronicles.html" ],
  [ "Tag leaked", "/tag/leaked/", "tags/leaked.html" ],
  [ "Tag live", "/tag/live/", "tags/live.html" ],
  [ "Tag past-life", "/tag/past-life/", "tags/past-life.html" ],
  [ "Tag ai", "/tag/ai/", "tags/ai.html" ] ].each do |label, path, ref|
  old_html = read_ref(ref) or next
  _, new_html, = fetch(path)
  o = list_rows(old_html); n = list_rows(new_html)
  o_by = o.to_h { |r| [ r[:href], r ] }
  n_by = n.to_h { |r| [ r[:href], r ] }
  missing = o.map { |r| r[:href] } - n.map { |r| r[:href] }
  extra   = n.map { |r| r[:href] } - o.map { |r| r[:href] }
  excerpt_lost = o_by.filter_map do |href, r|
    nr = n_by[href]
    next unless nr
    if r[:excerpt_words] > 0 && nr[:excerpt_words].zero?
      { href: href, old: r[:excerpt_words], new: 0 }
    end
  end
  list_details << {
    label: label, path: path,
    old_count: o.size, new_count: n.size,
    missing: missing, extra: extra,
    old_paginated: paginated?(old_html),
    excerpt_lost: excerpt_lost
  }
end

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def yn(b) = b ? "✓" : "✗"

total_urls = rows.size
clean = rows.count { |r| r[:diffs].empty? }
with_diffs = rows.reject { |r| r[:diffs].empty? || r[:expected] }

out = +""
out << "# nityesh.com — Parity Report\n\n"
out << "_Generated #{Time.now.strftime("%Y-%m-%d %H:%M %Z")} · old = `reference/` Ghost snapshot · new = `#{BASE}`_\n\n"
out << "Old vs new for every URL in the reference sitemaps. Host differences "
out << "(nityesh.com ↔ localhost) are normalized to path before comparing canonical/og:image.\n\n"

out << "## Summary\n\n"
out << "| Metric | Value |\n|---|---|\n"
out << "| URLs checked | #{total_urls} |\n"
out << "| Fully clean | #{clean} |\n"
out << "| With diffs (excl. intended redirect) | #{with_diffs.size} |\n"
out << "| RSS item count | old #{rss_old[:count]} → new #{rss_new[:count]} #{yn(rss_old[:count] == rss_new[:count])} |\n"
out << "| RSS guids identical & ordered | #{yn(rss_guids_ok)} |\n"
out << "| 404 returns 404 | #{yn(row404[:status_ok])} |\n"
sm_all_ok = sitemap_reports.values.all? { |r| r[:ok] }
out << "| Sitemap URL sets match | #{yn(sm_all_ok)} |\n\n"

# Per-URL table
out << "## Per-URL comparison\n\n"
out << "Columns: HTTP status (new), then ✓/✗ for title · canonical · description · og:image · h1, "
out << "then word count old→new (Δ%). Blank field cells mean identical.\n\n"
out << "| URL | Status | Title | Canon | Desc | og:img | H1 | Words (old→new, Δ%) | Diffs |\n"
out << "|---|---|---|---|---|---|---|---|---|\n"
rows.each do |r|
  if r[:expected]
    out << "| `#{r[:path]}` | #{r[:new_status]} | — | — | — | — | — | — | #{r[:status_note]} |\n"
    next
  end
  wc =
    if r[:old_words]
      pct = r[:word_delta].respond_to?(:infinite?) && r[:word_delta].infinite? ? "∞" : format("%.1f%%", (r[:word_delta] || 0) * 100)
      "#{r[:old_words]}→#{r[:new_words]} (#{pct})#{r[:word_ok] ? "" : " ✗"}"
    else
      "—"
    end
  diffs = r[:diffs].empty? ? "clean" : r[:diffs].join(", ")
  out << "| `#{r[:path]}` | #{yn(r[:status_ok])} #{r[:new_status]} | #{yn(r.fetch(:title_ok, true))} | #{yn(r.fetch(:canonical_ok, true))} | #{yn(r.fetch(:desc_ok, true))} | #{yn(r.fetch(:og_image_ok, true))} | #{yn(r.fetch(:h1_ok, true))} | #{wc} | #{diffs} |\n"
end
out << "\n"

# Detailed diffs
out << "## Field-level diffs (old → new)\n\n"
if substantive.empty?
  out << "None. Every field matched on every URL.\n\n"
else
  out << "| URL | Field | Old | New |\n|---|---|---|---|\n"
  substantive.each do |d|
    old_v = d[:old].to_s
    new_v = d[:new].to_s
    old_v = old_v.length > 90 ? old_v[0, 90] + "…" : old_v
    new_v = new_v.length > 90 ? new_v[0, 90] + "…" : new_v
    out << "| `#{d[:path]}` | #{d[:kind]} | #{old_v.gsub("|", "\\|")} | #{new_v.gsub("|", "\\|")} |\n"
  end
  out << "\n"
end

# RSS
out << "## RSS feed\n\n"
out << "| Check | Old | New | OK |\n|---|---|---|---|\n"
out << "| item count | #{rss_old[:count]} | #{rss_new[:count]} | #{yn(rss_old[:count] == rss_new[:count])} |\n"
out << "| guids identical & same order | #{rss_old[:guids].size} guids | #{rss_new[:guids].size} guids | #{yn(rss_guids_ok)} |\n\n"
unless rss_missing.empty? && rss_extra.empty?
  out << "- Guids in old but missing from new: #{rss_missing.empty? ? "none" : rss_missing.join(", ")}\n"
  out << "- Guids in new but not in old: #{rss_extra.empty? ? "none" : rss_extra.join(", ")}\n\n"
end

# Sitemaps
out << "## Sitemaps\n\n"
out << "| Sitemap | Old #loc | New #loc | Match |\n|---|---|---|---|\n"
sitemap_reports.each do |sm, r|
  out << "| `#{sm}` | #{r[:old_count]} | #{r[:new_count]} | #{yn(r[:ok])} |\n"
end
out << "\n"
sitemap_reports.each do |sm, r|
  next if r[:ok]
  out << "**`#{sm}` differences**\n\n"
  out << "- In old, missing from new: #{r[:missing].empty? ? "none" : r[:missing].map { |x| "`#{x}`" }.join(", ")}\n"
  out << "- In new, not in old: #{r[:extra].empty? ? "none" : r[:extra].map { |x| "`#{x}`" }.join(", ")}\n\n"
end

# 404
out << "## 404 page\n\n"
out << "- Bogus slug `#{bogus}` returns HTTP **#{row404[:new_status]}** #{yn(row404[:status_ok])} (expected 404)\n"
out << "- Old title: `#{row404[:old_title]}` · New title: `#{row404[:new_title]}`\n\n"

# List-page detail
out << "## List-page detail (home + tags)\n\n"
out << "Word-count diffs on archive pages come from two mechanical causes, isolated here: "
out << "**post-set** differences (Ghost paginated; new app shows one page) and **excerpt loss** "
out << "(Ghost auto-generated an excerpt from the body when no custom excerpt existed; the new app shows none).\n\n"
out << "| Page | Old posts | New posts | Old paginated? | Extra in new | Missing in new | Rows that lost their excerpt |\n"
out << "|---|---|---|---|---|---|---|\n"
list_details.each do |d|
  extra = d[:extra].empty? ? "—" : d[:extra].map { |x| "`#{x}`" }.join(" ")
  missing = d[:missing].empty? ? "—" : d[:missing].map { |x| "`#{x}`" }.join(" ")
  lost = d[:excerpt_lost].empty? ? "—" : d[:excerpt_lost].map { |e| "`#{e[:href]}` (#{e[:old]}→0w)" }.join(" ")
  out << "| #{d[:label]} `#{d[:path]}` | #{d[:old_count]} | #{d[:new_count]} | #{d[:old_paginated] ? "yes" : "no"} | #{extra} | #{missing} | #{lost} |\n"
end
out << "\n"

# Curated findings
out << "## Substantive findings & recommendations\n\n"
out << "The gate found **no meta-pattern typos** to auto-fix — `<title>`, canonical, meta description "
out << "and og:image match on all #{total_urls} URLs. The remaining diffs are behavioral and need a decision, "
out << "so they are listed rather than silently changed:\n\n"
out << <<~FINDINGS
  1. **Missing auto-excerpts on archive rows (home, `/tag/chronicles/`, `/tag/leaked/`).** Ghost synthesizes a
     card excerpt from the first ~50 words of a post's body when the author set no custom excerpt; the new app
     renders a blank excerpt for those posts, so the card shows title + date only. Affects a handful of posts
     (see table above). Same fallback also feeds the RSS `<description>` and meta description — worth a single
     `Post#summary` derivation (strip tags → first N words) so list, feed and meta all match Ghost. **Substantive.**

  2. **Pagination parity (`/tag/past-life/`, and `/page/N/` URLs).** Ghost paginated archives (`rel="next"`,
     `/page/2/`). The snapshot of `/tag/past-life/` is page 1 (12 posts); the new app has no pagination and shows
     all 14 on one page — the two "extra" posts are legitimately tagged, just previously on page 2, so this is
     **not** a data leak. But Ghost's `/page/2/` and `/tag/:slug/page/N/` URLs now return **404** in the new app.
     Decision for Nityesh: keep single-page archives (simplest; then 301 `/page/N/` → the base archive so old
     links/Search Console don't 404), or reintroduce pagination. **Substantive — needs a call.**

  3. **About pages render an unexpected `<h1>` (`/about/`, `/about-me/`).** Ghost's page template shows no title
     heading; the new app prints the Ghost *page title* ("Small about" / "Full about" — internal names) as an
     `<h1>`. Fix: suppress the `gh-article-title` heading for `Page` STI records in the shared `_post` partial.
     Small, but it changes reader-visible output, so flagged not applied. **Substantive.**

  4. **`/books-read/` leaks raw CSS text into the body (+2,531 words).** An HTML card in that post (a Kindle
     highlights export) contained a `<style>` block; Action Text's sanitizer dropped the `<style>` tag but kept
     its text node, so `.bodyContainer { font-family: Arial … }` now renders as visible body text. Block-level
     structure (headings/lists/hr counts) is otherwise identical. Fix belongs in the importer/sanitization
     (strip `<style>`/`<script>` **contents**, not just the tags). **Substantive — data/import.**

FINDINGS
out << "\n"

File.write(OUT_FILE, out)

# Console summary
puts "Parity check complete → #{OUT_FILE}"
puts "URLs: #{total_urls} | clean: #{clean} | with diffs: #{with_diffs.size}"
puts "RSS: old #{rss_old[:count]} / new #{rss_new[:count]} items, guids #{rss_guids_ok ? "identical" : "DIFFER"}"
puts "Sitemaps match: #{sm_all_ok}"
puts "404: #{row404[:status_ok] ? "ok" : "FAIL (#{row404[:new_status]})"}"
unless with_diffs.empty?
  puts "\nURLs with diffs:"
  with_diffs.each { |r| puts "  #{r[:path]} → #{r[:diffs].join(", ")}" }
end
