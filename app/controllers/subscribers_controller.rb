class SubscribersController < ApplicationController
  allow_unauthenticated_access

  # Unauthenticated, public endpoint — throttle so a script can't stuff the table.
  rate_limit to: 10, within: 1.minute, only: :create

  # Idempotent and discreet: a duplicate signup takes the same happy path as a fresh
  # one, so we never leak whether an address was already on the list. Pre-normalise
  # the value so find_or_create_by's WHERE clause matches the stored (stripped,
  # downcased) form rather than tripping the uniqueness validation on a re-signup.
  def create
    @subscriber = Subscriber.find_or_create_by(email: Subscriber.normalize_value_for(:email, params[:email]))

    if @subscriber.persisted?
      respond_to do |format|
        format.turbo_stream # create.turbo_stream.erb — the confirmation
        format.html { redirect_to root_url(anchor: "subscribe"), notice: "First class. You're on the list." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("subscribe_form", partial: "subscribers/form", locals: { subscriber: @subscriber }),
                 status: :unprocessable_entity
        end
        format.html { redirect_to root_url(anchor: "subscribe"), alert: "That address didn't look right. Try again?" }
      end
    end
  end
end
