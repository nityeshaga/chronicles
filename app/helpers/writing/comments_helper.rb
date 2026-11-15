module Writing::CommentsHelper
  # What the margin listens for, on the editor shell. The prose changing and the window
  # resizing both move what a comment is pinned to; a selection is how one is started.
  def comments_actions
    %w[
      lexxy:change->comments#remeasure
      resize@window->comments#remeasure
      focus@window->comments#refresh
      selectionchange@document->comments#selected
      keydown.meta+alt+m@window->comments#compose:prevent
      keydown.ctrl+alt+m@window->comments#compose:prevent
      turbo:before-cache@window->comments#beforeCache
    ].join(" ")
  end

  # When it was said, in the words a margin uses; the exact time is a hover away.
  def comment_stamp(comment)
    tag.time time_ago_in_words(comment.created_at) + " ago", datetime: comment.created_at.utc.iso8601,
      title: comment.created_at.strftime("%-d %b %Y, %H:%M"), class: "comment__when"
  end
end
