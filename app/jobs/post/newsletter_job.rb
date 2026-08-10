class Post::NewsletterJob < ApplicationJob
  # Fan the issue out one deliver_later per subscriber rather than mailing the whole
  # list in a single job, so one subscriber's delivery failure retries in isolation
  # (see config/initializers/action_mailer.rb) instead of re-mailing everyone. The
  # enqueue loop itself isn't checkpointed — a re-run of *this* job would re-enqueue
  # the list — but it's pure DB work, done in milliseconds, and never retried on its
  # own; the risky slow half (talking to Postmark) is what's isolated per subscriber.
  def perform(post)
    Subscriber.find_each do |subscriber|
      NewsletterMailer.issue(post, subscriber).deliver_later
    end
  end
end
