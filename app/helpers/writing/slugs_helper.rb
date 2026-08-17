module Writing::SlugsHelper
  # Everything the slug check needs to ask its question, wherever it rides: where to ask,
  # and which record mustn't be counted against itself. Blank on a new post — autosave
  # announces the id the moment it mints the draft.
  def slug_check_values(post)
    { slug_url_value: writing_slug_path, slug_post_id_value: post.id }
  end
end
