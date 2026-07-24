xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9",
           "xmlns:image" => "http://www.google.com/schemas/sitemap-image/1.1" do
  @posts.each do |post|
    xml.url do
      xml.loc public_post_url(post)
      xml.lastmod ghost_time(post.updated_at)
      if post.feature_image.present?
        xml.tag! "image:image" do
          xml.tag! "image:loc", site_url(post.feature_image)
          xml.tag! "image:caption", File.basename(post.feature_image)
        end
      end
    end
  end
end
