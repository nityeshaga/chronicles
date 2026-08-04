require "test_helper"
require "json"

# Field-by-field SEO parity with Ghost's rendered <head> and sitemap tree.
# Ground truth is reference/ (the saved Ghost HTML/XML).
class SeoMetaTest < ActionDispatch::IntegrationTest
  include ApplicationHelper # ghost_time — the same formatter the views use

  setup { @post = posts(:published) }

  test "post head carries the full meta + OG + Twitter + article set" do
    get post_url(@post, trailing_slash: true)
    assert_response :success

    canonical = "http://www.example.com/#{@post.slug}/"
    image     = "http://www.example.com#{@post.feature_image}"

    assert_select "title", text: @post.title
    assert_select "link[rel=canonical][href=?]", canonical
    assert_select "meta[name=description][content=?]", @post.meta_description

    assert_select "body.post-template"
    assert_select "meta[property='og:type'][content=article]"
    assert_select "meta[property='og:site_name'][content=?]", Setting.current.site_title
    assert_select "meta[property='og:title'][content=?]", @post.title
    assert_select "meta[property='og:url'][content=?]", canonical
    assert_select "meta[property='og:image'][content=?]", image
    assert_select "meta[property='article:published_time'][content=?]", ghost_time(@post.published_at)
    assert_select "meta[property='article:modified_time'][content=?]", ghost_time(@post.updated_at)
    assert_select "meta[property='article:tag'][content=chronicles]"

    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name='twitter:image'][content=?]", image
    assert_select "meta[name='twitter:label1'][content='Written by']"
    assert_select "meta[name='twitter:data1'][content=?]", Setting.current.author_name
    assert_select "meta[name='twitter:label2'][content='Filed under']"
    assert_select "meta[name='twitter:site'][content=?]", Setting.current.twitter_handle

    assert_select "link[rel=alternate][type='application/rss+xml']"
  end

  test "post emits a JSON-LD Article matching Ghost's shape" do
    get post_url(@post, trailing_slash: true)
    data = json_ld(response.body)

    assert_equal "https://schema.org", data["@context"]
    assert_equal "Article", data["@type"]
    assert_equal @post.title, data["headline"]
    assert_equal "http://www.example.com/#{@post.slug}/", data["url"]
    assert_equal ghost_time(@post.published_at), data["datePublished"]
    assert_equal ghost_time(@post.updated_at), data["dateModified"]
    assert_equal "chronicles", data["keywords"]
    assert_equal "Organization", data.dig("publisher", "@type")
    assert_equal Setting.current.site_title, data.dig("publisher", "name")
    assert_equal "Person", data.dig("author", "@type")
    assert_equal Setting.current.author_name, data.dig("author", "name")
    # Ghost points mainEntityOfPage at the site root, not the canonical.
    assert_equal "http://www.example.com/", data.dig("mainEntityOfPage", "@id")
  end

  test "omits <meta name=description> when the post has no explicit description" do
    @post.update!(meta_description: nil, excerpt: nil)
    get post_url(@post, trailing_slash: true)
    assert_select "meta[name=description]", count: 0
    # ...but social cards still get a derived description.
    assert_select "meta[property='og:description']"
  end

  test "homepage emits a WebSite JSON-LD" do
    get root_url
    data = json_ld(response.body)
    assert_equal "WebSite", data["@type"]
    assert_equal "http://www.example.com/", data["url"]
    assert_select "meta[property='og:title'][content=?]", Setting.current.site_title
    assert_select "title", text: Setting.current.home_meta_title
  end

  test "tag archive emits a Series JSON-LD and its own title" do
    get tag_url(tags(:chronicles).slug, trailing_slash: true)
    data = json_ld(response.body)
    assert_equal "Series", data["@type"]
    assert_equal "chronicles", data["name"]
    assert_select "title", text: "chronicles - #{Setting.current.site_title}"
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/tag/chronicles/"
  end

  test "page (STI) is website type but still emits an Article JSON-LD" do
    get post_url(posts(:about), trailing_slash: true)
    assert_select "body.page-template"
    assert_select "meta[property='og:type'][content=website]"
    assert_select "meta[property='article:published_time']", count: 0
    assert_equal "Article", json_ld(response.body)["@type"]
  end

  test "sitemap index points at four children with lastmods" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", response.media_type
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    locs = doc.xpath("//sitemap/loc").map(&:text)
    assert_includes locs, sitemap_posts_url
    assert_includes locs, sitemap_pages_url
    assert_includes locs, sitemap_tags_url
    assert_includes locs, sitemap_authors_url
    assert doc.xpath("//sitemap/lastmod").any? { |n| n.text.end_with?("Z") }
  end

  test "sitemap-posts lists posts with trailing slashes, lastmod and feature image" do
    get sitemap_posts_url
    assert_response :success
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    assert_includes doc.xpath("//url/loc").map(&:text),
      "http://www.example.com/#{@post.slug}/"
    assert_includes doc.xpath("//url/lastmod").map(&:text), ghost_time(@post.updated_at)
    assert_includes doc.xpath("//image/loc").map(&:text),
      "http://www.example.com#{@post.feature_image}"
    assert_includes doc.xpath("//image/caption").map(&:text), "dhh-race-1.jpeg"
  end

  test "sitemap-pages leads with the homepage then lists pages" do
    get sitemap_pages_url
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    locs = doc.xpath("//url/loc").map(&:text)
    assert_equal "http://www.example.com/", locs.first
    assert_includes locs, "http://www.example.com/about/"
  end

  # An HTML page is a Page by STI, so it lists itself in the pages sitemap for free —
  # which is how a hand-authored landing page inherits the site's search presence.
  test "sitemap-pages lists a published HTML page with a trailing-slash loc" do
    get sitemap_pages_url
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    assert_includes doc.xpath("//url/loc").map(&:text),
      "http://www.example.com/#{posts(:html_page).slug}/"
  end

  test "an HTML page stays out of the posts sitemap and the feed" do
    get sitemap_posts_url
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    assert_not_includes doc.xpath("//url/loc").map(&:text),
      "http://www.example.com/#{posts(:html_page).slug}/"

    get "/rss/"
    assert_no_match posts(:html_page).title, response.body
  end

  test "sitemap-authors carries the author archive url" do
    get sitemap_authors_url
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    assert_equal "http://www.example.com/#{Setting.current.author_path}", doc.xpath("//url/loc").first.text
  end

  test "robots.txt advertises the sitemap and blocks the writing UI" do
    get "/robots.txt"
    assert_response :success
    assert_match %r{Sitemap: https://nityesh\.com/sitemap\.xml}, response.body
    assert_match %r{Disallow: /writing/}, response.body
  end

  test "post response is ETagged and answers 304 to a matching If-None-Match" do
    get post_url(@post, trailing_slash: true)
    etag = response.headers["ETag"]
    assert etag.present?
    get post_url(@post, trailing_slash: true), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  private
    def json_ld(html)
      script = Nokogiri::HTML(html).at_css('script[type="application/ld+json"]')
      JSON.parse(script.text)
    end
end
