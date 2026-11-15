# frozen_string_literal: true

module CommentToolSupport
  private
    def serialize_thread(thread)
      {
        id: thread.id,
        quote: thread.quote,
        # False once the passage has been rewritten: the comment is still about what it
        # quotes, but the words are no longer in the doc to point at.
        quote_found: (!thread.orphaned? if thread.quote.present?),
        resolved_at: thread.resolved_at&.iso8601,
        comments: [ thread, *thread.replies ].map { |comment| serialize_comment(comment) }
      }.compact
    end

    def serialize_comment(comment)
      { id: comment.id, author: comment.author_name, body: comment.body, created_at: comment.created_at.iso8601 }
    end
end
