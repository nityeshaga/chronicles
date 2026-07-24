class Post::PublishJob < ApplicationJob
  def perform(post, scheduled_for)
    post.publish_if_due(scheduled_for)
  end
end
