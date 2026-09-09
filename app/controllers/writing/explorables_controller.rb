# The explorable editor is the HTML-page editor with a file list under it: the front
# document is raw_html and edits like any HTML page; the companion files are read here and
# written only through the MCP tools, because a directory of decks is nothing to type into
# a form. Creation lives with the tools for the same reason.
class Writing::ExplorablesController < Writing::HtmlPagesController
  # The only honest preview of a bundle is the bundle at its own address, where its relative
  # links resolve — and a signed-in writer sees a draft explorable there (Post.viewable).
  def show
    redirect_to post_path(@post, trailing_slash: true)
  end

  private
    def set_html_page
      @post = Explorable.find_by!(slug: params[:id])
    end

    def html_page_params
      params.require(:explorable).permit(:title, :slug, :raw_html)
    end
end
