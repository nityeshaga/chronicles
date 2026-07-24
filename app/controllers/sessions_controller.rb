class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  # Throttle password guessing: the Rails 8 auth generator ships this line and its
  # absence was a deviation. Backed by solid_cache_store in production.
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(email_address: params[:email_address], password: params[:password])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_url, alert: "Wrong email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to root_url
  end
end
