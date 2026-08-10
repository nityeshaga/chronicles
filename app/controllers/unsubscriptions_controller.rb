class UnsubscriptionsController < ApplicationController
  allow_unauthenticated_access

  # Reached from the footer link (GET) and from Gmail/Apple Mail's one-click button
  # (POST) alike. A subscriber is a plain row, so unsubscribing is destroying it —
  # there's no unsubscribed flag to carry. The signed token names its own purpose and
  # can't be forged; a spent or malformed token simply finds nothing and lands on the
  # same confirmation, so the page is safe and idempotent whichever way it's hit.
  def show
    Subscriber.find_signed(params[:token], purpose: :unsubscribe)&.destroy
  end
end
