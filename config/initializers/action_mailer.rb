# Newsletter fan-out reliability. Postmark hiccups (timeouts, 5xx) are worth
# retrying — each subscriber's delivery is its own job, so a retry re-mails no one
# else. An ApiInputError (inactive/suppressed recipient and kin) is Postmark's
# permanent no: retrying the identical input can't succeed, so discard rather than
# poison the queue.
Rails.application.config.to_prepare do
  ActionMailer::MailDeliveryJob.retry_on Postmark::TimeoutError, Postmark::InternalServerError,
    wait: :polynomially_longer, attempts: 5
  ActionMailer::MailDeliveryJob.discard_on Postmark::ApiInputError
end
