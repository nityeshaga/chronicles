xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9",
           "xmlns:image" => "http://www.google.com/schemas/sitemap-image/1.1" do
  xml.url do
    xml.loc site_url(Setting.current.author_path)
    xml.lastmod ghost_time(@lastmod) if @lastmod
  end
end
