# The shelves: one page per kind of thing in the log, and the essays by era. Each is a
# filtered read of the same ships the homepage lists, so nothing here is a second source.
class ShelvesController < ApplicationController
  allow_unauthenticated_access
  # /tools once had its own shelf; it's the apps page now. Redirecting /tools straight there
  # avoids a redirect to a redirect via /tools/.
  skip_before_action :redirect_to_trailing_slash, only: :tools

  def apps
    @apps = Ship.log.app.with_attached_preview.with_attached_poster.includes(:post)
    fresh_when etag: @apps
  end

  def tools
    redirect_to "#{apps_path}/", status: :moved_permanently
  end

  def explorables
    @ships = Ship.log.explorable.with_attached_preview.with_attached_poster.includes(:post)
    fresh_when etag: @ships
  end

  def comics
    @ships = Ship.log.comic.with_attached_preview.with_attached_poster.includes(:post)
    fresh_when etag: @ships
  end

  def essays
    @eras = Tag.eras.reverse
    @current = @eras.shift
    @articles = @current ? @current.posts.articles.published.ordered : Post.none
    fresh_when etag: [ @eras, @articles.to_a ]
  end
end
