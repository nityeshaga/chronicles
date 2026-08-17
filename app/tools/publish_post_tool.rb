# frozen_string_literal: true

class PublishPostTool < ActionTool::Base
  include PostToolSupport

  tool_name "publish_post"
  description "Publish a draft now, or schedule it for a future time with `at`. Delegates to the model's publish verbs — timestamp flooring, schedule-identity, and job enqueue are handled there. Re-call with a new `at` to reschedule. Returns the public URL."
  annotations(
    title: "Publish Post",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:id_or_slug).filled.description("The post's numeric id or its slug string.")
    optional(:at).filled(:string).description("ISO8601 time to publish at (must be in the future), e.g. '2026-08-01T09:00:00Z'. Omit to publish immediately.")
  end

  def call(id_or_slug:, at: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    post = resolve_post(id_or_slug)
    return ToolErrors::POST_NOT_FOUND unless post

    if at.present?
      begin
        time = Time.iso8601(at.to_s)
      rescue ArgumentError
        return { error: "Could not parse 'at' as ISO8601. Use a form like '2026-08-01T09:00:00Z'." }
      end
    end

    # One verb for both branches, and the model's own words for every refusal — an
    # untitled post, a time already gone. The rule lives in one place, so a new one
    # reaches the agent without touching this tool.
    return { error: post.errors.full_messages.to_sentence } unless post.publish(at: time)

    {
      status: status_of(post),
      published_at: post.published_at&.iso8601,
      url: (public_url(post) if post.published?),
      message: post.published? ? "Published and live." : "Scheduled. It goes live automatically; call unpublish_post to cancel."
    }
  end
end
