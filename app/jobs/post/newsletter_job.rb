class Post::NewsletterJob < ApplicationJob
  # Fan the issue out one deliver_later per subscriber rather than mailing the whole
  # list in a single job. Each subscriber's send then retries in isolation, so one bad
  # address can't re-mail the people already reached — the duplicate-on-retry trap a
  # single looping job would fall into.
  def perform(post)
    Subscriber.find_each do |subscriber|
      NewsletterMailer.issue(post, subscriber).deliver_later
    end
  end
end
