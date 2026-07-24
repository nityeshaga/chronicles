module AdoptsFeatureImage
  extend ActiveSupport::Concern

  private
    # When a save carried a native feature-image upload, adopt the blob's stable path
    # into the feature_image URL column. Keeping the column as the single source of
    # truth means every existing renderer — public views, RSS, sitemaps, social meta —
    # consumes the upload with no changes; the attachment is just where the bytes live.
    # A relative blob path (not an absolute URL) matches the Ghost /content/images
    # shape the renderers already expect, so site_url() prefixes the host uniformly.
    def adopt_feature_image_upload(record)
      return if params.dig(record.model_name.param_key, :uploaded_feature_image).blank?

      record.update_column :feature_image, rails_blob_path(record.uploaded_feature_image, only_path: true)
    end
end
