# frozen_string_literal: true

class AllowNullSecretOnOauthApplications < ActiveRecord::Migration[8.1]
  def change
    change_column_null :oauth_applications, :secret, true
  end
end
