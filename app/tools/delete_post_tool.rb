# frozen_string_literal: true

class DeletePostTool < ActionTool::Base
  include PostToolSupport

  tool_name "delete_post"
  description "Permanently delete a post or page. Requires confirm: true. Called with confirm false/omitted it deletes nothing and returns a preview of what would be destroyed — re-call with confirm: true to go through with it."
  annotations(
    title: "Delete Post",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:id_or_slug).filled.description("The post's numeric id or its slug string.")
    required(:confirm).filled(:bool).description("Must be true to actually delete. Pass false first to preview what will be destroyed.")
  end

  def call(id_or_slug:, confirm:)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    post = resolve_post(id_or_slug)
    return ToolErrors::POST_NOT_FOUND unless post

    summary = { id: post.id, slug: post.slug, title: post.title, kind: kind_of(post), status: status_of(post) }

    unless confirm == true
      return {
        requires_confirmation: true,
        would_delete: summary,
        message: "Nothing deleted. Re-call delete_post with confirm: true to permanently delete this."
      }
    end

    if post.destroy
      { success: true, deleted: summary }
    else
      { error: post.errors.full_messages.presence&.join(", ") || "The post could not be deleted." }
    end
  end
end
