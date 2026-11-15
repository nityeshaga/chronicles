# frozen_string_literal: true

class ListCommentsTool < ActionTool::Base
  include PostToolSupport
  include CommentToolSupport

  tool_name "list_comments"
  description "The threads in a doc's margin. Each is pinned to a passage (quote) and holds the comment that opened it and every reply, oldest first, with who said it. Open threads are the conversation in progress: read them before editing the doc, answer with add_comment, and resolve_comment once what a thread asked for is done."
  annotations(
    title: "List Comments",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:doc).filled.description("The doc's numeric id or slug, from create_post or list_posts(kind: 'doc').")
    optional(:status).filled(:string).description("'open' (default), 'resolved' or 'all'.")
  end

  def call(doc:, status: "open")
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    found = resolve_doc(doc)
    return ToolErrors::DOC_NOT_FOUND unless found

    threads = case status
    when "open"     then found.comments.threads.open
    when "resolved" then found.comments.threads.resolved
    when "all"      then found.comments.threads
    else return { error: "status must be 'open', 'resolved' or 'all'." }
    end

    { doc: { id: found.id, title: found.title, edit_url: edit_url(found) },
      threads: threads.ordered.includes(:replies).map { |thread| serialize_thread(thread) } }
  end
end
