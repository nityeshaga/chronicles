class PostsController < ApplicationController
  allow_unauthenticated_access

  def index
    # The whole feed for RSS (index.rss.erb); the HTML homepage takes only the top
    # three for its "latest from the press" strip and shelves the eras below that.
    @posts = Post.articles.published.ordered
    @eras = Tag.eras.select { |era| era.published_article_count.positive? }
    @machines = Machine.all
    # A signup redirect carries a one-time flash; skip conditional-GET so a cached
    # ETag can't 304 the confirmation/error away before it's seen. The machines
    # digest is in the ETag because the shelf reshuffles without any post changing.
    fresh_when etag: [ @posts, Machine.cache_key ], last_modified: @posts.maximum(:updated_at) unless flash.any?
  end

  def show
    # Unfiltered on purpose: pages (About, etc) are served through here too.
    @post = Post.published.find_by!(slug: params[:slug])
    fresh_when @post
    return if performed? # fresh_when already answered a 304; rendering again would raise

    # An HTML page IS its response: no layout, so no masthead, footer, app CSS/JS or
    # templated meta — the stored document already carries all of that, and any byte
    # we add is a byte that wasn't in the design. html_safe is the point, not a hole:
    # raw_html is writable only by an authenticated writer, the same trust boundary
    # the Action Text body already sits behind. fresh_when above still ETags it.
    render html: @post.raw_html.html_safe, layout: false if @post.is_a?(HtmlPage)
  end
end
