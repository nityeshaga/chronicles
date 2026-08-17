# Is this URL still free? Asked from the editor as the writer types, answered as a
# turbo-frame the field swaps in place — so what counts as "free" stays here, on the
# server, and never has to be re-implemented (or drift) in JavaScript.
class Writing::SlugsController < Writing::BaseController
  layout false

  def show
    @state = state_for(params[:id].to_s.strip)
  end

  private
    # Three answers, not two. Taken: some post already holds the slug — every kind shares
    # one table and one uniqueness constraint, so a Page's slug blocks a Post's. Reserved:
    # public posts live at the root, alongside /rss, /writing, /sitemap.xml and the rest,
    # so the router — not a hand-kept denylist — says which names are already spoken for.
    def state_for(slug)
      return if slug.blank?
      return :taken if taken?(slug)
      return :reserved unless routable?(slug)

      :available
    end

    # The record being edited doesn't take its own slug; the editor sends the one it
    # arrived with as `except`.
    def taken?(slug)
      slug != params[:except] && Post.exists?(slug: slug)
    end

    # Free means the router resolves this exact path back to this exact post slug. Asking
    # for the slug too (not just posts#show) catches the names a route would swallow —
    # "notes.md" recognizes as the post "notes" in the "md" format, which is not this post.
    def routable?(slug)
      route = Rails.application.routes.recognize_path("/#{slug}/")
      route[:controller] == "posts" && route[:action] == "show" && route[:slug] == slug
    rescue ActionController::RoutingError
      false
    end
end
