# frozen_string_literal: true

class AddRegistrationFieldsToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :registration_type, :string, default: "manual", null: false
    add_column :oauth_applications, :client_uri, :string
    add_column :oauth_applications, :logo_uri, :string
    add_column :oauth_applications, :metadata_cached_at, :datetime
  end
end
