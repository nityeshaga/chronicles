# The shelves: one page per kind of thing in the log, and the essays by era. Each is a
# filtered read of the same ships the homepage lists, so nothing here is a second source.
class ShelvesController < ApplicationController
  allow_unauthenticated_access
  # /tools is a redirect; sending it to /tools/ first would be a redirect to a redirect.
  skip_before_action :redirect_to_trailing_slash, only: :tools

  def apps
    @apps  = Ship.log.app.with_attached_preview.with_attached_poster.includes(:post)
    @tools = Ship.log.tool.on_github
    fresh_when etag: [ @apps, @tools ]
  end

  def tools
    redirect_to "#{apps_path}/#tools", status: :moved_permanently
  end

  def explorables
    @ships = Ship.log.explorable
    fresh_when etag: @ships
  end

  def comics
    @ships = Ship.log.comic
    fresh_when etag: @ships
  end

  def essays
    @eras = Tag.eras.reverse
    @current = @eras.shift
    @articles = @current ? @current.posts.articles.published.ordered : Post.none
    @drafts = Post.in_the_typewriter
    fresh_when etag: [ @eras, @articles.to_a, @drafts.to_a ]
  end
end
