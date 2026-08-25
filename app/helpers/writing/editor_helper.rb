module Writing::EditorHelper
  # What the save indicator prints once a save lands. A live post's save republished the
  # page, so it says so rather than offering a bare reassurance. Stamped onto the form for
  # the autosave controller to read, so this copy is written once, in Ruby.
  def autosave_saved_text(post)
    return "Saved · live" if post.published?

    post.scheduled? ? "Saved · scheduled" : "Saved"
  end

  # The line it opens with, as [ state, text ]. A new post opens silent — nothing has been
  # saved, so there is nothing to report. A persisted one never does, and a live one names
  # what the next save costs before a key is pressed rather than after it. A page reached
  # by a refused save (the alert below the bar says why) must not open on "Saved": the
  # writer's work did not land, and the bar says only what the canvas is showing.
  # The one word in the bar's count that changes with the number. It rides the element as
  # data as well as being printed, because the bar rewrites that line on every keystroke
  # and the copy stays Ruby's on both passes.
  WORD_UNITS = { one: "word", many: "words" }.freeze

  def word_unit(count) = count == 1 ? WORD_UNITS[:one] : WORD_UNITS[:many]

  def word_unit_data = { word_one: WORD_UNITS[:one], word_many: WORD_UNITS[:many] }

  def autosave_idle_status(post)
    return [ nil, nil ] unless post.persisted?
    return [ nil, "Showing the saved version" ] if flash[:alert].present?
    return [ "live", "Live · saves go public" ] if post.published?

    [ "saved", autosave_saved_text(post) ]
  end
end
