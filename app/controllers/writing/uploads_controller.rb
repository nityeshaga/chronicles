# Binary uploads for agents: a plain multipart POST authenticated with the same
# ApiToken bearer header the /mcp transport uses (never the session cookie), so
# Claude Code / Luo Ji can `curl -F file=@cover.png` a local image and get back the
# exact { url, figure_html } shape upload_image returns. Binary doesn't belong in an
# MCP tool call; the auth model is shared, the response shape is shared (UploadedImage).
class Writing::UploadsController < ApplicationController
  allow_unauthenticated_access only: :create
  skip_forgery_protection only: :create
  before_action :authenticate_api_token, only: :create

  MAX_BYTES = 10.megabytes

  def create
    file = params[:file]
    return render_error("Missing file. Send a multipart form with a 'file' field.") if file.blank?

    content_type = file.content_type.to_s
    return render_error("Only image uploads are accepted (got #{content_type.presence || "unknown"}).") unless content_type.start_with?("image/")
    return render_error("Image is over the 10 MB limit.") if file.size.to_i > MAX_BYTES

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: content_type
    )

    render json: UploadedImage.new(blob, alt: params[:alt], caption: params[:caption]).to_h, status: :created
  end

  private
    def authenticate_api_token
      header = request.env["HTTP_AUTHORIZATION"]
      token = header.to_s.start_with?("Bearer ") ? header.sub("Bearer ", "") : nil
      api_token = ApiToken.find_by_token(token)

      if api_token.nil? || api_token.expired?
        render json: { error: "Invalid or missing API token. Send Authorization: Bearer <token>." }, status: :unauthorized
      else
        api_token.touch_last_used!
      end
    end

    def render_error(message)
      render json: { error: message }, status: :unprocessable_entity
    end
end
