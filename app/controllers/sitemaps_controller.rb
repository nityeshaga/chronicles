class SitemapsController < ApplicationController
  allow_unauthenticated_access

  # Sitemap index → four children, matching Ghost's structure. Each child's lastmod
  # is the freshest record in its set; the whole tree ETags off those maxima.
  def index
    @posts_lastmod   = Post.articles.published.maximum(:updated_at)
    @pages_lastmod   = [ Page.published.maximum(:updated_at), @posts_lastmod ].compact.max
    @tags_lastmod    = Tag.maximum(:updated_at)
    @authors_lastmod = @posts_lastmod
    fresh_when etag: [ @pages_lastmod, @posts_lastmod, @tags_lastmod ]
  end

  def posts
    @posts = Post.articles.published.order(updated_at: :desc)
    fresh_when @posts
  end

  def pages
    @home_lastmod = Post.published.maximum(:updated_at)
    @pages = Page.published.order(updated_at: :desc)
    fresh_when etag: [ @home_lastmod, @pages.to_a ]
  end

  def tags
    @tags = Tag.order(updated_at: :desc)
    fresh_when @tags
  end

  def authors
    @lastmod = Post.published.maximum(:updated_at)
    fresh_when etag: @lastmod
  end
end
