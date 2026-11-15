# frozen_string_literal: true

class AddCommentTool < ActionTool::Base
  include PostToolSupport
  include CommentToolSupport

  tool_name "add_comment"
  description "Say something in a doc's margin. Pass reply_to to answer a thread — the usual case, since most threads are the author's and are waiting on you. Without it this opens a new thread: pass quote to pin it to a passage, copied exactly as the words read in the doc, or leave quote out for a remark about the doc as a whole. The author sees it beside the prose the next time the margin refreshes."
  annotations(
    title: "Add Comment",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:doc).filled.description("The doc's numeric id or slug.")
    required(:body).filled(:string).description("What to say. Plain text; blank lines make paragraphs.")
    optional(:reply_to).filled(:integer).description("The id of the thread being answered, from list_comments. Omit to open a new thread.")
    optional(:quote).filled(:string).description("New threads only: the passage to pin the thread to, as plain text exactly as it reads in the doc — a phrase or a sentence from one paragraph, with no HTML. If it appears more than once the first is used, so quote enough to be unique.")
    optional(:author).filled(:string).description("Your name, shown on the comment (default: Luo).")
  end

  def call(doc:, body:, reply_to: nil, quote: nil, author: "Luo")
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    found = resolve_doc(doc)
    return ToolErrors::DOC_NOT_FOUND unless found

    thread = found.comments.threads.find_by(id: reply_to) if reply_to
    return ToolErrors::COMMENT_NOT_FOUND if reply_to && !thread
    return { error: "A reply is pinned to its thread, not to a passage — drop quote, or drop reply_to to open a new thread." } if thread && quote.present?

    comment = found.comments.new(parent: thread, body: body, quote: quote, author_name: author)
    # Refused rather than saved as an orphan: a quote the doc doesn't contain is a comment
    # the author would find at the foot of the margin, pointing at nothing.
    return { error: "That quote isn't in the doc as plain text. Call get_post to re-read the body and copy the passage as it reads, without HTML tags." } if comment.orphaned?

    if comment.save
      serialize_thread(comment.parent || comment).merge(edit_url: edit_url(found))
    else
      { error: comment.errors.full_messages.join(", ") }
    end
  end
end
