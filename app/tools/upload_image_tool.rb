# frozen_string_literal: true

class UploadImageTool < ActionTool::Base
  include ImageFetching

  tool_name "upload_image"
  description "Fetch an image from a public http(s) URL, store it, and return a permanent URL plus a ready-to-paste kg-image-card figure. Use this for images already on the web; for a local file, curl POST /writing/uploads instead. The server does the fetching so image bytes never pass through this tool call. Pass the url as feature_image for a cover, or splice figure_html into a body via update_post body_patches."
  annotations(
    title: "Upload Image",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: true
  )

  arguments do
    required(:source_url).filled(:string).description("Public http:// or https:// URL of the image to fetch and store.")
    optional(:alt).filled(:string).description("Alt text for the image.")
    optional(:caption).filled(:string).description("Caption. When given it becomes the figure's figcaption.")
    optional(:filename).filled(:string).description("Filename to store the blob under. Derived from the URL or content type when omitted.")
  end

  def call(source_url:, alt: nil, caption: nil, filename: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    fetched = fetch_remote_image(source_url)
    return fetched if fetched.is_a?(Hash)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(fetched.bytes),
      filename: filename_for(source_url, fetched.content_type, filename),
      content_type: fetched.content_type
    )

    image = UploadedImage.new(blob, alt: alt, caption: caption)
    {
      url: image.url,
      figure_html: image.figure_html,
      message: "Stored. Pass url as feature_image on create_post/update_post for a cover, or splice figure_html into the body with update_post body_patches — the patch's 'old' anchor must appear exactly once in the body."
    }
  end

  private
    def filename_for(source_url, content_type, provided)
      return provided.strip if provided.present?

      base = File.basename(URI.parse(source_url).path.to_s)
      return base if base.present? && base.include?(".")

      "image.#{content_type.split("/").last.split("+").first}"
    rescue URI::InvalidURIError
      "image.#{content_type.split("/").last.split("+").first}"
    end
end
