class Page < Post
  def og_type = "website"
  def body_class = "page-template"
  def article_meta? = false
  def show_title? = false
end
