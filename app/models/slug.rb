# A name the writer is trying on for a URL. "Is it free?" is one question with one answer,
# asked both by the editor as they type and by Post#generate_slug when it invents one — so
# what counts as taken is defined here, once, rather than once per caller.
class Slug
  attr_reader :text

  # `except` is the id of the record being edited: a post doesn't take its own slug. An id,
  # never a copy of the slug — a slug the editor is holding goes stale the moment the
  # record is saved under a different one, and then the post is told its own URL is taken.
  # Blank on a new post, until autosave mints the draft and hands its id over.
  def initialize(text, except: nil)
    @text = text.to_s.strip
    @except = except.presence
  end

  # Three answers, not two, and a blank name asks nothing. Taken: some post already holds
  # it — every kind shares one table and one uniqueness constraint, so a Page's slug blocks
  # a Post's. Reserved: public posts live at the root, alongside /rss, /writing,
  # /sitemap.xml and the rest, so the router — not a hand-kept denylist — says which names
  # are already spoken for.
  def state
    return if text.blank?
    return :taken if taken?
    return :reserved if reserved?

    :available
  end

  def taken?
    Post.where.not(id: @except).exists?(slug: text)
  end

  # Free means the router resolves this exact path back to this exact post slug. Asking for
  # the slug too (not just posts#show) catches the names a route would swallow — "notes.md"
  # recognizes as the post "notes" in the "md" format, which is not this post. A name the
  # router can't route at all, like one with a space in it, is unusable the same way.
  def reserved?
    route = Rails.application.routes.recognize_path("/#{text}/")
    route[:controller] != "posts" || route[:action] != "show" || route[:slug] != text
  rescue ActionController::RoutingError
    true
  end
end
