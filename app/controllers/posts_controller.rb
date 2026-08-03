class PostsController < ApplicationController
  allow_unauthenticated_access

  def index
    # The whole feed for RSS (index.rss.erb); the HTML homepage takes only the top
    # three for its "latest from the press" strip and shelves the eras below that.
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
