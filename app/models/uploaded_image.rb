# Wraps a stored Active Storage blob and hands back the two things every image
# path (the upload_image tool and POST /writing/uploads) must return in one shape:
# a permanent absolute URL and a ready-to-paste kg-image-card figure. The URL uses
# the blob-redirect route (rails_blob_url) — the same permanent, non-expiring form
# adopts_feature_image relies on, so it's safe to persist as feature_image or embed
# in a body. The figure markup mirrors lib/ghost/mobiledoc.rb's card_image exactly,
# so agent-uploaded images render through the identical Ghost-parity path as imported ones.
class UploadedImage
  def initialize(blob, alt: nil, caption: nil)
    @blob = blob
    @alt = alt.to_s.strip
    @caption = caption.to_s.strip
  end

  def url
    Rails.application.routes.url_helpers.rails_blob_url(
      @blob,
      host: Setting.current.production_host,
      protocol: "https"
    )
  end

  def figure_html
    %(<figure class="kg-card kg-image-card#{@caption.present? ? " kg-card-hascaption" : ""}">#{img_tag}#{figcaption}</figure>)
  end

  def to_h
    { url: url, figure_html: figure_html }
  end

  private
    def img_tag
      tag = %(<img src="#{ERB::Util.html_escape(url)}")
      tag << %( alt="#{ERB::Util.html_escape(@alt)}") if @alt.present?
      tag << ">"
    end

    def figcaption
      @caption.present? ? %(<figcaption>#{ERB::Util.html_escape(@caption)}</figcaption>) : ""
    end
end
