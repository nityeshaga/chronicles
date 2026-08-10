class NewsletterMailer < ApplicationMailer
  # One issue to one subscriber. Post::NewsletterJob fans the list out one call at a
  # time, so this only ever addresses a single recipient — which is also what lets the
  # unsubscribe link be personal and one-click.
  def issue(post, subscriber)
    @post = post
    # Trailing slash to match the site's canonical form, so the link never eats a 301
    # (which would also drop a mail client's one-click POST).
    @unsubscribe_url = unsubscribe_url(token: subscriber.signed_id(purpose: :unsubscribe), trailing_slash: true)

    # RFC 8058 one-click unsubscribe: Gmail and Apple Mail surface a native
    # "Unsubscribe" button that POSTs to this URL and destroys the row; the visible
    # footer link GETs the same URL and lands on a confirmation page first (see
    # UnsubscriptionsController for why GET must stay safe).
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail(
      to: subscriber.email,
      # The address matches the Postmark-verified sender domain, so it stays literal.
      from: email_address_with_name("newsletter@nityesh.com", Setting.current.author_name),
      subject: post.title,
      # Bulk mail must ride a Postmark broadcast stream; "broadcast" is the server's
      # default broadcast stream. Ignored by the :test/:file delivery methods.
      message_stream: "broadcast"
    )
  end
end
