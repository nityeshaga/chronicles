class Page < Post
  def og_type = "website"
  def body_class = "page-template"
  def article_meta? = false
  def show_title? = false
  def newsletterable? = false
  def dashboard_bucket = "page"
  def taggable? = false
end
