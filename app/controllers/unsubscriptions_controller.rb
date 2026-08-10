class UnsubscriptionsController < ApplicationController
  allow_unauthenticated_access

  # The RFC 8058 one-click POST comes from the mail client's servers — no session,
  # no CSRF token — so the forgery check would 422 it. The signed token is the
  # credential; it names its own purpose and can't be forged.
  skip_forgery_protection

  # The footer link. GET must stay safe — corporate link scanners and prefetchers
  # follow every URL in an email, and a destructive GET would let them silently
  # unsubscribe people — so this only asks. A spent or malformed token finds nobody
  # and shows the goodbye instead, keeping the flow idempotent however it's reached.
  def show
    @subscriber = Subscriber.find_signed(params[:token], purpose: :unsubscribe)
    render :destroy if @subscriber.nil?
  end

  # Destroying the row is the unsubscribe — no flag to rot. Reached by the page's
  # button and by Gmail/Apple Mail's native one-click POST alike.
  def destroy
    Subscriber.find_signed(params[:token], purpose: :unsubscribe)&.destroy
  end
end
