# frozen_string_literal: true

class ResolveCommentTool < ActionTool::Base
  include CommentToolSupport

  tool_name "resolve_comment"
  description "Resolve a thread in a doc's margin once what it asked for is done. Pass reply to say in one line what changed — it is added to the thread first, so the author reads the answer where he asked the question. Resolved threads fold away at the foot of the margin; only the author reopens one."
  annotations(
    title: "Resolve Comment",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:id).filled(:integer).description("The thread's id, from list_comments.")
    optional(:reply).filled(:string).description("One line on what changed, e.g. 'Cut the second example and merged the two paragraphs.'")
    optional(:author).filled(:string).description("Your name, shown on the reply (default: Luo).")
  end

  def call(id:, reply: nil, author: "Luo")
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    thread = Comment.threads.find_by(id: id)
    return ToolErrors::COMMENT_NOT_FOUND unless thread

    thread.replies.create!(body: reply, author_name: author) if reply.present? && !thread.resolved?
    thread.resolve unless thread.resolved?
    serialize_thread(thread.reload)
  end
end
