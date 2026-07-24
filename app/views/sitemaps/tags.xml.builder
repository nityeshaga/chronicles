xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9",
           "xmlns:image" => "http://www.google.com/schemas/sitemap-image/1.1" do
  @tags.each do |tag|
    xml.url do
      xml.loc public_tag_url(tag.slug)
      xml.lastmod ghost_time(tag.updated_at)
    end
  end
end
