class Writing::ConnectedAppsController < ApplicationController
  layout "writing"

  # revoke_all_for scopes by resource owner, so a user can only ever disconnect
  # their own tokens — an unknown or someone else's application id revokes nothing.
  def destroy
    Doorkeeper::AccessToken.revoke_all_for(params[:id], Current.user)
    redirect_to writing_connect_url, notice: "Disconnected."
  end
end
