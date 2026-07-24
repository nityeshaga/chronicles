xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9",
           "xmlns:image" => "http://www.google.com/schemas/sitemap-image/1.1" do
  xml.url do
    xml.loc root_url
    xml.lastmod ghost_time(@home_lastmod) if @home_lastmod
  end
  @pages.each do |page|
    xml.url do
      xml.loc public_post_url(page)
      xml.lastmod ghost_time(page.updated_at)
      if page.feature_image.present?
        xml.tag! "image:image" do
          xml.tag! "image:loc", site_url(page.feature_image)
          xml.tag! "image:caption", File.basename(page.feature_image)
        end
      end
    end
  end
end
