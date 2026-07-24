# frozen_string_literal: true

class UnpublishPostTool < ActionTool::Base
  include PostToolSupport

  tool_name "unpublish_post"
  description "Revert a post to draft. If it had a pending publish schedule, that schedule is cancelled."
  annotations(
    title: "Unpublish Post",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:id_or_slug).filled.description("The post's numeric id or its slug string.")
  end

  def call(id_or_slug:)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    post = resolve_post(id_or_slug)
    return ToolErrors::POST_NOT_FOUND unless post

    post.unpublish

    {
      status: status_of(post),
      note: "Now a draft. Any pending publish schedule was cancelled."
    }
  end
end
