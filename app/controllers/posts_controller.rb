class PostsController < ApplicationController
  allow_unauthenticated_access

  # The article feed at /rss (index.rss.erb). The HTML homepage is the ship log now
  # (ships#index); this action has no HTML template.
  def index
    @posts = Post.articles.published.ordered
    fresh_when etag: @posts, last_modified: @posts.maximum(:updated_at)
  end

  def show
    # Unfiltered on purpose: pages (About, etc) and explorables are served through here too.
    @post = Post.viewable(writer: signed_in?).find_by!(slug: params[:slug])
    # A page shows the house's numbers beside its prose, so they validate it too.
    fresh_when etag: [ @post, *@post.try(:house_numbers)&.values ], last_modified: @post.updated_at
    return if performed? # fresh_when already answered a 304; rendering again would raise

    # An HTML page IS its response: no layout, so no masthead, footer, app CSS/JS or
    # templated meta — the stored document already carries all of that, and any byte
    # we add is a byte that wasn't in the design. html_safe is the point, not a hole:
    # raw_html is writable only by an authenticated writer, the same trust boundary
    # the Action Text body already sits behind. fresh_when above still ETags it.
    render html: html_page_document.html_safe, layout: false if @post.is_a?(HtmlPage)
  end

  private
    # The author gets the red pen on HTML pages too. The document owns its own <head>, so
    # the gem splices the rail in before </body> (or appends it, if the document has none),
    # and only on the author's copy; a reader's bytes are the stored bytes.
    def html_page_document
      signed_in? ? helpers.redpen_inject(@post.raw_html, path: requested_path) : @post.raw_html
    end
end
