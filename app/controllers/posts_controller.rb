class PostsController < ApplicationController
  allow_unauthenticated_access

  def index
    # Still loaded for the RSS feed (index.rss.erb); the HTML homepage no longer
    # renders the feed — it shelves the eras instead.
    @posts = Post.articles.published.ordered
    @eras = Tag.eras.select { |era| era.published_article_count.positive? }
    # A signup redirect carries a one-time flash; skip conditional-GET so a cached
    # ETag can't 304 the confirmation/error away before it's seen.
    fresh_when @posts unless flash.any?
  end

  def show
    # Unfiltered on purpose: pages (About, etc) are served through here too.
    @post = Post.published.find_by!(slug: params[:slug])
    fresh_when @post
  end
end
