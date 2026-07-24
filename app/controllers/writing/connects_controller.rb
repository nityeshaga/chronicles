class Writing::ConnectsController < ApplicationController
  layout "writing"

  def show
    @api_token = Current.user.api_tokens.build
    @api_tokens = Current.user.api_tokens.order(created_at: :desc)

    authorized = Doorkeeper::AccessToken.where(resource_owner_id: Current.user.id, revoked_at: nil)
    @connected_apps = Doorkeeper::Application.where(id: authorized.select(:application_id)).order(:created_at)
    @last_issued_at = authorized.group(:application_id).maximum(:created_at)
  end
end
