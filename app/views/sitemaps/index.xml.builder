xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.sitemapindex "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  {
    sitemap_pages_url   => @pages_lastmod,
    sitemap_posts_url   => @posts_lastmod,
    sitemap_authors_url => @authors_lastmod,
    sitemap_tags_url    => @tags_lastmod
  }.each do |loc, lastmod|
    xml.sitemap do
      xml.loc loc
      xml.lastmod ghost_time(lastmod) if lastmod
    end
  end
end
