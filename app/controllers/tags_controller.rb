class TagsController < ApplicationController
  allow_unauthenticated_access

  def show
    @tag = Tag.find_by!(slug: params[:slug])
    @posts = @tag.posts.articles.published.ordered
    fresh_when etag: [ @tag, @posts.to_a ]
  end
end
